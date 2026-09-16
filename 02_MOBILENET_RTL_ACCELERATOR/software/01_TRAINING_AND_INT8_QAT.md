# Training and INT8 QAT

## Model and dataset

MobileNetV1 software flow는 `timm`의 pretrained `mobilenetv1_100`에서 시작합니다.

- input: 224×224
- ImageNet / ILSVRC2012 training-validation flow
- MobileNetV1 depthwise-separable convolution 구조 유지

## QAT configuration

PyTorch FBGEMM QAT configuration을 사용합니다.

- activation: **per-tensor asymmetric affine quantization**
- weight: **per-channel symmetric quantization**
- FakeQuant / Observer를 학습 graph에 삽입해 activation과 weight 분포를 추적

즉, 단순 post-training conversion이 아니라 학습 중 quantization effect를 포함한 **Quantization-Aware Training**입니다.

## Fine-tuning

QAT fine-tuning에는 다음 구성을 사용했습니다.

- `RandomResizedCrop(224)`
- `RandomHorizontalFlip`
- `ColorJitter`
- ImageNet normalization
- batch size 64
- AdamW
- label smoothing 0.1
- CosineAnnealingLR
- 20 epochs

## Software result

| Metric | FP32 | INT8 QAT |
|---|---:|---:|
| Top-1 Accuracy | 69.64% | **69.24%** |
| Top-5 Accuracy | 89.20% | **88.79%** |
| Model Size | 약 16.67 MB | **약 4.40 MB** |

CPU/GPU software inference time은 FPGA accelerator FPS와 다른 측정 경계이므로 hardware 성능 수치와 직접 비교하지 않습니다.

## Engineering meaning

이 단계에서 얻는 결과는 단순한 accuracy number가 아니라 이후 RTL이 사용해야 할 **INT8 weight와 activation quantization state의 출발점**입니다.
