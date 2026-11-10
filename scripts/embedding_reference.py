#!/usr/bin/env python3
"""EmbeddingGemma 2 q4f16 参考实现（验收 #1 golden 的生成脚本）。

Dart 移植（lib/services/embedding_session.dart + gemma_tokenizer.dart）必须
逐位复现这里的配方，用 test/fixtures/embedding_golden.json 对拍：
  - 查询：前缀 'task: search result | query: {q}'，tokenize 后 [bos]+ids+[eos]
  - 图片：resize 320x224（拉伸，非等比）→ float /255（无 normalize，无 mean/std）
          → 16x16 patch 展平 [1,280,768]（行主序 patch；patch 内像素行主序、RGB 交织）
          → pixel_position_ids [1,280,2] = (row,col) 网格
  - 融合：视觉塔输出 n×512 行；文本塔 input_ids 用**单个** <|image|> 占位
          （本脚本 [2,4642,IMG,1]，与真机 integration_test 一致），
          image_features=n 行原样喂入，video/audio_features 传 [0,512] 空张量
  - 输出：sentence_embedding（第 2 输出）768 维，图内已 L2 归一化
环境：pip install onnxruntime tokenizers pillow；图与 tokenizer.json 放同目录
（外部数据 .onnx_data 必须同名同目录）。随机 N(0,1) 张量会 NaN/±FLT_MAX，
golden 必须用真实 0–1 像素图。
"""
import json, sys
from pathlib import Path
import numpy as np
from PIL import Image
from tokenizers import Tokenizer
import onnxruntime as ort

IMG = 258880  # <|image|>
ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else '.')

tok = Tokenizer.from_file(str(ROOT / 'tokenizer.json'))
vis = ort.InferenceSession(str(ROOT / 'vision_encoder_q4f16.onnx'), providers=['CPUExecutionProvider'])
txt = ort.InferenceSession(str(ROOT / 'model_q4f16.onnx'), providers=['CPUExecutionProvider'])
EMPTY = np.zeros((0, 512), dtype=np.float32)

def embed_text(q: str):
    ids = [2] + tok.encode(f'task: search result | query: {q}').ids[:512] + [1]
    x = np.array([ids], np.int64)
    return txt.run(None, {'input_ids': x, 'attention_mask': np.ones_like(x),
                          'image_features': EMPTY, 'video_features': EMPTY,
                          'audio_features': EMPTY})[1][0]

def embed_image(path):
    a = np.asarray(Image.open(path).convert('RGB').resize((320, 224)), np.float32) / 255.0
    px = a.reshape(14, 16, 20, 16, 3).transpose(0, 2, 1, 3, 4).reshape(1, 280, 768)
    pid = np.stack([np.repeat(np.arange(14), 20), np.tile(np.arange(20), 14)], 1)[None]
    f = vis.run(None, {'pixel_values': px.astype(np.float32), 'pixel_position_ids': pid})[0]
    ids = np.array([[2, 4642, IMG, 1]], np.int64)
    return txt.run(None, {'input_ids': ids, 'attention_mask': np.ones_like(ids),
                          'image_features': f.astype(np.float32), 'video_features': EMPTY,
                          'audio_features': EMPTY})[1][0]

if __name__ == '__main__':
    out = {'note': 'single <|image|> placeholder; ids=[2,4642,IMG,1]; ORT ' + ort.__version__}
    print('golden generation: pass a portrait path; see docstring')
