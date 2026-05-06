use tantivy::tokenizer::{BoxTokenStream, TextAnalyzer, Token, Tokenizer};

#[derive(Clone)]
pub struct SimpleCjkTokenizer;

impl Tokenizer for SimpleCjkTokenizer {
    type TokenStream<'a> = SimpleCjkTokenStream;

    fn token_stream(&self, text: &str) -> SimpleCjkTokenStream {
        let mut tokens = Vec::new();
        let chars: Vec<char> = text.chars().collect();
        let len = chars.len();

        let mut i = 0;
        let mut byte_offset = 0;
        while i < len {
            let c = chars[i];
            let c_len = c.len_utf8();

            if c.is_alphanumeric() {
                let start = i;
                let start_byte = byte_offset;

                let mut chunk = String::new();
                while i < len {
                    let cc = chars[i];
                    if cc.is_alphanumeric() {
                        chunk.push(cc);
                        byte_offset += cc.len_utf8();
                        i += 1;
                    } else {
                        break;
                    }
                }

                tokens.push(Token {
                    offset_from: start_byte,
                    offset_to: byte_offset,
                    position: tokens.len(),
                    text: chunk,
                    position_length: 1,
                });

                if chunk.len() > 2 && chunk.chars().all(|c| c.is_ascii_alphabetic()) {
                    let lower = chunk.to_lowercase();
                    tokens.last_mut().unwrap().text = lower;
                }
            } else if c.is_whitespace() {
                byte_offset += c_len;
                i += 1;
            } else {
                tokens.push(Token {
                    offset_from: byte_offset,
                    offset_to: byte_offset + c_len,
                    position: tokens.len(),
                    text: c.to_string(),
                    position_length: 1,
                });
                byte_offset += c_len;
                i += 1;
            }
        }

        SimpleCjkTokenStream {
            tokens,
            index: 0,
        }
    }
}

pub struct SimpleCjkTokenStream {
    tokens: Vec<Token>,
    index: usize,
}

impl TokenStream for SimpleCjkTokenStream {
    fn advance(&mut self) -> bool {
        if self.index < self.tokens.len() {
            self.index += 1;
            true
        } else {
            false
        }
    }

    fn token(&self) -> &Token {
        &self.tokens[self.index - 1]
    }

    fn token_mut(&mut self) -> &mut Token {
        &mut self.tokens[self.index - 1]
    }
}

pub fn create_cjk_analyzer() -> TextAnalyzer {
    TextAnalyzer::from(SimpleCjkTokenizer)
}
