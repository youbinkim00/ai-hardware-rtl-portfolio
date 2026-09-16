# MobileNetV1 Software / INT8 QAT

이 폴더는 MobileNetV1을 단순히 INT8로 변환한 결과가 아니라, **학습 → QAT → 정수 파라미터 생성 → RTL용 reference**까지 연결한 software flow를 정리합니다.

## Flow

```text
ImageNet pretrained MobileNetV1
        ↓
INT8 QAT
        ↓
Fully quantized INT8 model
        ↓
weight / scale / zero-point 추출
        ↓
INT32 bias + integer requant parameter
        ↓
layer-wise integer reference
        ↓
RTL / FPGA comparison
```

## Key evidence

- `timm` MobileNetV1 pretrained model 기반
- FBGEMM QAT
  - activation: per-tensor asymmetric
  - weight: per-channel symmetric INT8
- 224×224 ImageNet training / validation flow
- AdamW + label smoothing + CosineAnnealingLR
- FP32 대비 INT8 QAT 정확도와 model size 비교
- INT8 weight, INT32 bias, requant multiplier/shift 생성
- Stem 및 DWC/PWC layer를 따라가는 integer reference 경로 구성

## Documents

- [01 · Training and INT8 QAT](01_TRAINING_AND_INT8_QAT.md)
- [02 · Integer Export and Requantization](02_INTEGER_EXPORT_AND_REQUANTIZATION.md)
- [03 · Software–RTL Reference](03_SOFTWARE_RTL_REFERENCE.md)

> 전체 training notebook, trained checkpoint와 parameter payload는 public repository에 포함하지 않습니다.
