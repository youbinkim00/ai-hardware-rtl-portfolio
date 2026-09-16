# Distillation and Checkpoint Selection

[← Software overview](README.md)

## Why distillation was used

4-bit weight와 저정밀 activation으로 내려가면 단순 detection loss만으로는 floating-point teacher가 가진 intermediate representation을 유지하기 어렵습니다.

이를 위해 low-bit fine-tuning framework에 다음 auxiliary signal을 구성했습니다.

```text
YOLO detection loss
        +
box distillation
        +
object/class distillation
        +
feature distillation
```

## Implemented losses

| Component | Implementation |
|---|---|
| Detection loss | native YOLO detection loss |
| Box KD | Smooth L1 |
| Object/class KD | MSE |
| Feature KD | channel-normalized feature map + MSE |

Feature KD는 선택된 late-stage feature boundary에서 teacher/student output을 hook으로 수집해 계산했습니다.

## Optimization controls

Low-bit fine-tuning에서는 model parameter와 quantization-related parameter의 learning rate를 분리할 수 있도록 optimizer group을 나눴습니다.

또한 다음 안정화 장치를 함께 사용했습니다.

- frozen BN statistics
- EMA
- gradient clipping
- validation-based best checkpoint selection
- early stopping
- quantization configuration hard-check

## Important result interpretation

Distillation을 사용했다는 사실 자체를 accuracy improvement로 주장하지 않습니다.

final mixed-precision checkpoint를 고정한 뒤 수행한 short fine-tuning은 validation mAP@0.5:0.95를 기존 best보다 높이지 못했습니다. 따라서 더 오래 학습된 checkpoint가 아니라 **fine-tuning 이전의 validated best checkpoint를 최종 모델로 유지**했습니다.

이 선택은 다음 원칙을 보여줍니다.

> Training technique의 존재보다 validation evidence를 우선한다.

즉, KD는 low-bit optimization을 위한 regularization/representation-preservation 도구로 사용했지만, 최종 결과는 항상 best validation evidence에 의해 선택했습니다.

## Public claim boundary

공개 문서에서는 KD loss의 역할과 checkpoint selection policy를 설명합니다.  
정확한 layer hook name, 내부 training experiment history와 세부 coefficient schedule은 notebook/private artifact로 유지합니다.
