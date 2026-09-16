# Training and ReLU Recovery

[← Software overview](README.md)

## Goal

첫 software stage의 목표는 두 가지입니다.

1. VOC20 detection에 대해 충분한 정확도를 가진 FP32 teacher를 확보
2. RTL 구현에 적합한 activation으로 바꾼 뒤 accuracy를 recovery

## Dataset split

학습 notebook에서 사용한 dataset contract는 다음과 같습니다.

| Purpose | Split |
|---|---|
| Train | VOC2007 train + VOC2012 train + VOC2012 val |
| Validation | VOC2007 val |
| Test | VOC2007 test |
| Classes | 20 |
| Input | 640×640 |

이 split을 training, QAT와 final test에서 일관되게 사용하도록 YAML을 별도로 생성했습니다.

## FP32 teacher

COCO pretrained `yolov5s.pt`에서 시작해 VOC20용 FP32 teacher를 학습했습니다.

주요 training configuration:

| Item | Setting |
|---|---|
| Image size | 640 |
| Batch size | 16 |
| Epochs | 180 |
| Optimizer | SGD |
| LR schedule | cosine |
| Early-stop patience | 40 |
| Initialization | COCO pretrained YOLOv5s |

`test2007` 결과:

| P | R | mAP@0.5 | mAP@0.5:0.95 |
|---:|---:|---:|---:|
| 82.74% | 79.45% | 85.53% | 62.18% |

## SiLU → ReLU conversion

최종 RTL datapath에서는 activation 구현 복잡도를 줄이기 위해 SiLU를 ReLU로 변경했습니다.

단순 문자열 변경으로 끝내지 않고 다음 gate를 사용했습니다.

```text
FP32 teacher checkpoint
        ↓
ReLU model construction
        ↓
teacher state_dict transfer
        ↓
missing keys == 0
unexpected keys == 0
        ↓
remaining SiLU == 0
        ↓
recovery training
```

즉, activation 변경 때문에 weight mapping 자체가 깨지지 않았는지 먼저 확인하고 학습을 시작했습니다.

## ReLU recovery

ReLU model은 teacher weight로 초기화한 뒤 160 epoch recovery training을 수행했습니다.

주요 설정:

| Item | Setting |
|---|---|
| Image size | 640 |
| Batch size | 16 |
| Epochs | 160 |
| Optimizer | SGD |
| Initial LR | 0.0045 |
| Final LR factor | 0.10 |
| Momentum | 0.937 |
| Weight decay | 0.00035 |
| Warmup | 3 epochs |
| MixUp / Copy-Paste | disabled |
| Mosaic | capped at 0.8 |
| LR schedule | cosine |

`test2007` 결과:

| P | R | mAP@0.5 | mAP@0.5:0.95 |
|---:|---:|---:|---:|
| 82.00% | 77.90% | 83.70% | 60.50% |

FP32 teacher보다 accuracy가 낮아졌지만, 이후 low-bit QAT를 시작하기 위한 hardware-friendly floating baseline을 확보했습니다.

## Engineering point

이 단계의 핵심은 “ReLU로 바꾸었다”가 아니라 다음 순서입니다.

- software graph 변경
- checkpoint structural compatibility 확인
- activation replacement completeness 확인
- accuracy recovery
- 이후 QAT의 initialization checkpoint로 고정

따라서 RTL 친화적 변경을 모델 정확도와 분리하지 않고 software acceptance gate 안에서 관리했습니다.
