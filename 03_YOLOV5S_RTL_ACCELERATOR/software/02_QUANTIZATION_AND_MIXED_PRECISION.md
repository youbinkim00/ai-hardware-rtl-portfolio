# Quantization and Mixed Precision

[← Software overview](README.md)

## INT8 QAT baseline

ReLU recovery checkpoint를 바로 4-bit로 낮추지 않고, 먼저 INT8 QAT baseline을 만들었습니다.  
이 단계는 quantization graph와 training loop가 정상적으로 동작하는지 확인하는 안정화 단계입니다.

Brevitas 기반 변환:

| Floating module | Quantized module | Public numeric rule |
|---|---|---|
| `Conv2d` | `QuantConv2d` | signed per-channel weight |
| `ReLU` | `QuantReLU` | unsigned per-tensor activation |

INT8 변환 후 확인한 구조:

- QuantConv2d: 60
- QuantReLU: 57
- remaining floating Conv2d: 0
- remaining standalone floating ReLU: 0
- remaining SiLU: 0

## INT8 QAT training

주요 configuration:

| Item | Setting |
|---|---|
| Weight / activation | W8 / A8 |
| Epochs | 60 |
| Batch size | 24 |
| Input | 640×640 |
| Optimizer | SGD + Nesterov |
| Initial LR | 1e-4 |
| Momentum | 0.937 |
| Weight decay | 5e-4 |
| LR schedule | cosine |
| BN running statistics | frozen from start |
| Activation-scale initialization | calibration forward, 8 batches |
| EMA | enabled |
| Gradient clipping | 10.0 for the first 5 epochs |

INT8 QAT best validation checkpoint는 epoch 55에서 선택되었습니다.

`test2007` 결과:

| P | R | mAP@0.5 | mAP@0.5:0.95 |
|---:|---:|---:|---:|
| 81.52% | 78.28% | 83.15% | 59.89% |

## Final low-precision policy

최종 target은 단순한 uniform W4/A4가 아닙니다.

```text
Weights
  └─ all convolution weights → W4

Activations
  ├─ model input → A8
  ├─ selected shared-source activations → A8
  └─ remaining activations → A4
```

선택적 A8는 전체 activation precision을 높이는 방식이 아니라, low-bit graph에서 상대적으로 민감하고 여러 downstream path에 영향을 주는 경계만 보호하기 위한 정책입니다.

## Configuration drift prevention

Mixed-precision model에서는 “의도한 module이 정말 A8인지”를 학습 코드의 가정에 맡기지 않았습니다.

final checkpoint export 전에:

- expected A8 set 생성
- actual bit-width map 추출
- missing A8 module 확인
- extra A8 module 확인
- 전체 convolution weight bit-width 확인

을 수행하고, expected/actual set이 정확히 일치할 때만 final test를 진행했습니다.

세부 internal module name은 공개하지 않지만, 최종 검증에서는 **입력 1개 + 선택된 shared-source activation 3개만 A8**, 나머지 activation은 A4이며 모든 convolution weight는 W4임을 hard-check했습니다.

## Final mixed-precision result

`test2007`:

| P | R | mAP@0.5 | mAP@0.5:0.95 |
|---:|---:|---:|---:|
| 82.15% | 74.06% | 80.48% | 55.94% |

이 값은 최종 low-precision software checkpoint의 test 결과이며, 이후 RTL integer conversion의 출발점입니다.

## Why this is a software–hardware co-design step

bit width는 checkpoint 용량만 줄이는 옵션이 아닙니다.

- weight width → MAC/storage/bandwidth에 영향
- activation width → feature-map storage/data movement에 영향
- selective higher precision → accuracy recovery와 datapath cost 사이의 trade-off
- scale placement → integer export와 RTL boundary를 결정

따라서 mixed precision은 software accuracy와 RTL cost를 동시에 고려해 결정했습니다.
