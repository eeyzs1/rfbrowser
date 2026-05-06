mod tokenizer;

use std::collections::HashMap;
use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::ptr;
use std::sync::Mutex;

use serde::Serialize;
use tantivy::collector::TopDocs;
use tantivy::query::QueryParser;
use tantivy::schema::*;
use tantivy::{doc, Index, IndexReader, IndexWriter, ReloadPolicy, Searcher, TantivyDocument};

use tokenizer::create_cjk_analyzer;

static mut NEXT_HANDLE: u32 = 1;
static mut INSTANCES: Option<Mutex<HashMap<u32, BridgeInstance>>> = None;

struct BridgeInstance {
    index: Index,
    schema: Schema,
    reader: IndexReader,
}

fn get_instances() -> &'static Mutex<HashMap<u32, BridgeInstance>> {
    unsafe {
        if INSTANCES.is_none() {
            INSTANCES = Some(Mutex::new(HashMap::new()));
        }
        INSTANCES.as_ref().unwrap()
    }
}

fn alloc_handle(instance: BridgeInstance) -> u32 {
    unsafe {
        let handle = NEXT_HANDLE;
        NEXT_HANDLE += 1;
        get_instances().lock().unwrap().insert(handle, instance);
        handle
    }
}

fn build_schema() -> Schema {
    let mut schema_builder = Schema::builder();

    let text_options = TextOptions::default()
        .set_indexing_options(
            TextFieldIndexing::default()
                .set_tokenizer("cjk")
                .set_index_option(IndexRecordOption::WithFreqsAndPositions),
        )
        .set_stored();

    schema_builder.add_text_field("id", STRING | STORED);
    schema_builder.add_text_field("title", text_options.clone());
    schema_builder.add_text_field("content", text_options);
    schema_builder.add_text_field("tags", STRING | STORED);
    schema_builder.add_text_field("file_path", STRING | STORED);

    schema_builder.build()
}

#[no_mangle]
pub extern "C" fn tantivy_bridge_init(index_path: *const c_char) -> u32 {
    let path = unsafe {
        if index_path.is_null() {
            return 0;
        }
        CStr::from_ptr(index_path).to_string_lossy().into_owned()
    };

    let schema = build_schema();
    let index = match Index::create_in_dir(&path, schema.clone()) {
        Ok(idx) => idx,
        Err(_) => {
            match Index::open_in_dir(&path) {
                Ok(idx) => idx,
                Err(_) => return 0,
            }
        }
    };

    index.tokenizers().register("cjk", create_cjk_analyzer());

    let reader = index
        .reader_builder()
        .reload_policy(ReloadPolicy::OnCommitWithDelay)
        .try_into()
        .unwrap();

    let instance = BridgeInstance {
        index,
        schema,
        reader,
    };

    alloc_handle(instance)
}

#[no_mangle]
pub extern "C" fn tantivy_bridge_index(
    handle: u32,
    id: *const c_char,
    title: *const c_char,
    content: *const c_char,
    tags: *const c_char,
    file_path: *const c_char,
) -> i32 {
    let instances = get_instances().lock().unwrap();
    let instance = match instances.get(&handle) {
        Some(inst) => inst,
        None => return -1,
    };

    let id_str = unsafe { CStr::from_ptr(id).to_string_lossy().into_owned() };
    let title_str = unsafe { CStr::from_ptr(title).to_string_lossy().into_owned() };
    let content_str = unsafe { CStr::from_ptr(content).to_string_lossy().into_owned() };
    let tags_str = unsafe { CStr::from_ptr(tags).to_string_lossy().into_owned() };
    let file_path_str = unsafe { CStr::from_ptr(file_path).to_string_lossy().into_owned() };

    let id_field = instance.schema.get_field("id").unwrap();
    let title_field = instance.schema.get_field("title").unwrap();
    let content_field = instance.schema.get_field("content").unwrap();
    let tags_field = instance.schema.get_field("tags").unwrap();
    let file_path_field = instance.schema.get_field("file_path").unwrap();

    let mut writer: IndexWriter = instance.index.writer(50_000_000).unwrap();

    let id_term = tantivy::Term::from_field_text(id_field, &id_str);
    writer.delete_term(id_term);

    let _ = writer.add_document(doc!(
        id_field => id_str,
        title_field => title_str,
        content_field => content_str,
        tags_field => tags_str,
        file_path_field => file_path_str,
    ));

    match writer.commit() {
        Ok(_) => {
            let _ = instance.reader.reload();
            0
        }
        Err(_) => -2,
    }
}

#[derive(Serialize)]
struct SearchResult {
    note_id: String,
    title: String,
    snippet: String,
    score: f32,
    file_path: String,
}

#[derive(Serialize)]
struct SearchResponse {
    hits: Vec<SearchResult>,
    total_count: u64,
}

#[no_mangle]
pub extern "C" fn tantivy_bridge_search(
    handle: u32,
    query_str: *const c_char,
    top_k: u32,
) -> *mut c_char {
    let instances = get_instances().lock().unwrap();
    let instance = match instances.get(&handle) {
        Some(inst) => inst,
        None => return ptr::null_mut(),
    };

    let query_text = unsafe {
        if query_str.is_null() {
            return ptr::null_mut();
        }
        CStr::from_ptr(query_str).to_string_lossy().into_owned()
    };

    let searcher: Searcher = instance.reader.searcher();

    let title_field = instance.schema.get_field("title").unwrap();
    let content_field = instance.schema.get_field("content").unwrap();

    let mut query_parser = QueryParser::for_index(&instance.index, vec![title_field, content_field]);
    query_parser.set_field_boost(title_field, 3.0);

    let query = match query_parser.parse_query(&query_text) {
        Ok(q) => q,
        Err(_) => return ptr::null_mut(),
    };

    let top_docs = match searcher.search(&query, &TopDocs::with_limit(top_k as usize)) {
        Ok(docs) => docs,
        Err(_) => return ptr::null_mut(),
    };

    let mut hits = Vec::new();

    for (score, doc_address) in top_docs {
        let doc: TantivyDocument = match searcher.doc(doc_address) {
            Ok(d) => d,
            Err(_) => continue,
        };

        let note_id = doc
            .get_first(instance.schema.get_field("id").unwrap())
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string();

        let title = doc
            .get_first(title_field)
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string();

        let content = doc
            .get_first(content_field)
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string();

        let file_path = doc
            .get_first(instance.schema.get_field("file_path").unwrap())
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string();

        let snippet = build_snippet(&content, &query_text, 200);

        hits.push(SearchResult {
            note_id,
            title,
            snippet,
            score,
            file_path,
        });
    }

    let response = SearchResponse {
        total_count: hits.len() as u64,
        hits,
    };

    let json = match serde_json::to_string(&response) {
        Ok(j) => j,
        Err(_) => return ptr::null_mut(),
    };

    match CString::new(json) {
        Ok(cs) => cs.into_raw(),
        Err(_) => ptr::null_mut(),
    }
}

fn build_snippet(content: &str, query: &str, max_len: usize) -> String {
    let query_lower = query.to_lowercase();
    let content_lower = content.to_lowercase();

    let char_indices: Vec<(usize, char)> = content.char_indices().collect();

    let mut best_pos = 0;
    let mut best_score = 0;

    for (i, _) in char_indices.iter().enumerate() {
        let mut score = 0;
        for q_term in query_lower.split_whitespace() {
            if q_term.is_empty() {
                continue;
            }
            let remaining = &content_lower[i..];
            if remaining.starts_with(q_term) {
                score += q_term.len() * 3;
            } else if remaining.contains(q_term) {
                score += q_term.len();
            }
        }
        if score > best_score {
            best_score = score;
            best_pos = i;
        }
    }

    let total_chars: usize = char_indices.len();
    let context_chars = max_len / 2;

    let start = if best_pos > context_chars {
        best_pos - context_chars
    } else {
        0
    };
    let end = (best_pos + max_len + context_chars).min(total_chars);

    let mut snippet = String::new();
    if start > 0 {
        snippet.push_str("...");
    }

    for i in start..end {
        let c = char_indices[i].1;
        snippet.push(c);
    }

    if end < total_chars {
        snippet.push_str("...");
    }

    for q_term in query_lower.split_whitespace() {
        if q_term.is_empty() {
            continue;
        }
        let lower_snippet = snippet.to_lowercase();
        let mut result = String::new();
        let mut pos = 0;
        while pos < snippet.len() {
            if lower_snippet[pos..].starts_with(q_term) {
                result.push_str("**");
                let end_pos = pos + q_term.len();
                result.push_str(&snippet[pos..end_pos]);
                result.push_str("**");
                pos = end_pos;
            } else {
                result.push(snippet.chars().nth(pos).unwrap());
                pos += 1;
            }
        }
        snippet = result;
    }

    snippet
}

#[no_mangle]
pub extern "C" fn tantivy_bridge_remove(handle: u32, note_id: *const c_char) -> i32 {
    let instances = get_instances().lock().unwrap();
    let instance = match instances.get(&handle) {
        Some(inst) => inst,
        None => return -1,
    };

    let id_str = unsafe {
        if note_id.is_null() {
            return -1;
        }
        CStr::from_ptr(note_id).to_string_lossy().into_owned()
    };

    let id_field = instance.schema.get_field("id").unwrap();
    let mut writer: IndexWriter = instance.index.writer(50_000_000).unwrap();

    let id_term = tantivy::Term::from_field_text(id_field, &id_str);
    let _ = writer.delete_term(id_term);

    match writer.commit() {
        Ok(_) => {
            let _ = instance.reader.reload();
            0
        }
        Err(_) => -2,
    }
}

#[no_mangle]
pub extern "C" fn tantivy_bridge_close(handle: u32) -> i32 {
    let mut instances = get_instances().lock().unwrap();
    match instances.remove(&handle) {
        Some(_) => 0,
        None => -1,
    }
}

#[no_mangle]
pub extern "C" fn tantivy_bridge_free_string(s: *mut c_char) {
    if !s.is_null() {
        unsafe {
            let _ = CString::from_raw(s);
        }
    }
}
