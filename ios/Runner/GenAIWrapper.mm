//
//  GenAIWrapper.m
//  Runner
//
//  Created by HarshaNCK on 2024-10-12.
//

#import "GenAIWrapper.h"
#include <onnxruntime-genai/ort_genai.h>
#include <onnxruntime-genai/ort_genai_c.h>
#include <string>

@implementation GenAIWrapper {
    OgaModel* _model;
    OgaTokenizer* _tokenizer;
}

- (BOOL)load:(NSString *)modelPath error:(NSError **)error {
    const char* modelPathCStr = [modelPath UTF8String];
    NSLog(@"GenAIWrapper: Loading model from path: %s", modelPathCStr);
    
    OgaResult* result = OgaCreateModel(modelPathCStr, &_model);
    if (result) {
        NSLog(@"GenAIWrapper: Failed to create model: %s", OgaResultGetError(result));
        if (error) {
            *error = [NSError errorWithDomain:@"GenAIWrapper"
                                         code:1001
                                     userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithUTF8String:OgaResultGetError(result)]}];
        }
        OgaDestroyResult(result);
        return false;
    }
    NSLog(@"GenAIWrapper: Model created successfully");
    
    result = OgaCreateTokenizer(_model, &_tokenizer);
    if (result) {
        NSLog(@"GenAIWrapper: Failed to create tokenizer: %s", OgaResultGetError(result));
        if (error) {
            *error = [NSError errorWithDomain:@"GenAIWrapper"
                                         code:1002
                                     userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithUTF8String:OgaResultGetError(result)]}];
        }
        OgaDestroyResult(result);
        return false;
    }
    NSLog(@"GenAIWrapper: Tokenizer created successfully");
    
    return true;
}


- (BOOL)inference:(nonnull NSString *)prompt withParams:(NSDictionary<NSString *, NSNumber *> *)params {
    NSLog(@"GenAIWrapper: Starting inference");
    
    // Create sequences
    OgaSequences* sequences = nullptr;
    OgaResult* result = OgaCreateSequences(&sequences);
    if (result) {
        NSLog(@"GenAIWrapper: Failed to create sequences: %s", OgaResultGetError(result));
        OgaDestroyResult(result);
        return false;
    }
    
    // Encode prompt
    result = OgaTokenizerEncode(_tokenizer, [prompt UTF8String], sequences);
    if (result) {
        NSLog(@"GenAIWrapper: Failed to encode: %s", OgaResultGetError(result));
        OgaDestroyResult(result);
        OgaDestroySequences(sequences);
        return false;
    }
    
    size_t inputTokenCount = OgaSequencesGetSequenceCount(sequences, 0);
    NSLog(@"GenAIWrapper: Encoded %zu input tokens", inputTokenCount);
    
    // Create generator params
    OgaGeneratorParams* genParams = nullptr;
    result = OgaCreateGeneratorParams(_model, &genParams);
    if (result) {
        NSLog(@"GenAIWrapper: Failed to create generator params: %s", OgaResultGetError(result));
        OgaDestroyResult(result);
        OgaDestroySequences(sequences);
        return false;
    }
    
    // Set search options
    OgaGeneratorParamsSetSearchNumber(genParams, "max_length", 1000);
    for (NSString *key in params) {
        id value = params[key];
        if ([value isKindOfClass:[NSNumber class]]) {
            double doubleValue = [(NSNumber *)value doubleValue];
            NSLog(@"GenAIWrapper: Setting param %@ = %f", key, doubleValue);
            OgaGeneratorParamsSetSearchNumber(genParams, [key UTF8String], doubleValue);
        }
    }
    
    // Create tokenizer stream
    OgaTokenizerStream* tokenizerStream = nullptr;
    result = OgaCreateTokenizerStream(_tokenizer, &tokenizerStream);
    if (result) {
        NSLog(@"GenAIWrapper: Failed to create tokenizer stream: %s", OgaResultGetError(result));
        OgaDestroyResult(result);
        OgaDestroyGeneratorParams(genParams);
        OgaDestroySequences(sequences);
        return false;
    }
    
    // Create generator
    OgaGenerator* generator = nullptr;
    result = OgaCreateGenerator(_model, genParams, &generator);
    if (result) {
        NSLog(@"GenAIWrapper: Failed to create generator: %s", OgaResultGetError(result));
        OgaDestroyResult(result);
        OgaDestroyTokenizerStream(tokenizerStream);
        OgaDestroyGeneratorParams(genParams);
        OgaDestroySequences(sequences);
        return false;
    }
    
    // Append input sequences
    result = OgaGenerator_AppendTokenSequences(generator, sequences);
    if (result) {
        NSLog(@"GenAIWrapper: Failed to append sequences: %s", OgaResultGetError(result));
        OgaDestroyResult(result);
        OgaDestroyGenerator(generator);
        OgaDestroyTokenizerStream(tokenizerStream);
        OgaDestroyGeneratorParams(genParams);
        OgaDestroySequences(sequences);
        return false;
    }
    NSLog(@"GenAIWrapper: Generator ready, starting token generation");
    
    // Generate tokens
    int tokenCount = 0;
    while (!OgaGenerator_IsDone(generator)) {
        result = OgaGenerator_GenerateNextToken(generator);
        if (result) {
            NSLog(@"GenAIWrapper: Failed to generate token: %s", OgaResultGetError(result));
            OgaDestroyResult(result);
            break;
        }
        
        size_t seqLen = OgaGenerator_GetSequenceCount(generator, 0);
        if (seqLen == 0) continue;
        
        const int32_t* seqData = OgaGenerator_GetSequenceData(generator, 0);
        int32_t newToken = seqData[seqLen - 1];
        
        tokenCount++;
        NSLog(@"GenAIWrapper: Token %d - ID: %d", tokenCount, newToken);
        
        // Decode using tokenizer stream
        const char* decodedChunk = nullptr;
        result = OgaTokenizerStreamDecode(tokenizerStream, newToken, &decodedChunk);
        if (result) {
            NSLog(@"GenAIWrapper: Failed to decode token: %s", OgaResultGetError(result));
            OgaDestroyResult(result);
            continue;
        }
        
        if (decodedChunk != nullptr && strlen(decodedChunk) > 0) {
            // IMPORTANT: Copy the string immediately as it's only valid until next Decode call
            std::string decodedStr(decodedChunk);
            NSLog(@"GenAIWrapper: Decoded: '%s' (len=%zu)", decodedStr.c_str(), decodedStr.length());
            
            // Log bytes for debugging
            NSMutableString *hexStr = [NSMutableString string];
            for (size_t i = 0; i < decodedStr.length() && i < 20; i++) {
                [hexStr appendFormat:@"%02X ", (unsigned char)decodedStr[i]];
            }
            NSLog(@"GenAIWrapper: Bytes: %@", hexStr);
            
            NSString* nsDecodedStr = [NSString stringWithUTF8String:decodedStr.c_str()];
            if (nsDecodedStr != nil && [nsDecodedStr length] > 0) {
                NSLog(@"GenAIWrapper: Sending to delegate: '%@'", nsDecodedStr);
                if (self.delegate && [self.delegate respondsToSelector:@selector(didGenerateToken:)]) {
                    [self.delegate didGenerateToken:nsDecodedStr];
                }
            } else {
                NSLog(@"GenAIWrapper: UTF-8 conversion failed for token");
            }
        }
    }
    
    NSLog(@"GenAIWrapper: Inference complete, generated %d tokens", tokenCount);
    
    // Cleanup
    OgaDestroyGenerator(generator);
    OgaDestroyTokenizerStream(tokenizerStream);
    OgaDestroyGeneratorParams(genParams);
    OgaDestroySequences(sequences);
    
    return true;
}

- (void)unload {
    NSLog(@"GenAIWrapper: Unloading model");
    if (_tokenizer) {
        OgaDestroyTokenizer(_tokenizer);
        _tokenizer = nullptr;
    }
    if (_model) {
        OgaDestroyModel(_model);
        _model = nullptr;
    }
}

@end
