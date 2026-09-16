# Software Verification and Reproducibility

[← Software overview](README.md) · [Verification Strategy](../docs/03_VERIFICATION_STRATEGY.md)

## Verification philosophy

이 프로젝트의 software 검증은 “모델이 실행된다”가 아니라 각 변환 단계에서 **무엇이 변해도 되고 무엇이 변하면 안 되는지**를 명시하는 방식으로 구성했습니다.

## Acceptance gates

### Checkpoint load

ReLU conversion과 quantized model reconstruction 시 state transfer를 검사했습니다.

```text
missing keys
unexpected keys
module type
device
quantization proxy state
```

구조적으로 의도한 차이 외의 key mismatch가 있으면 다음 단계로 진행하지 않습니다.

### Activation replacement

SiLU → ReLU conversion 후 residual SiLU가 남아 있는지 확인했습니다.

### Quantization graph

INT8 QAT baseline에서는:

- QuantConv2d count
- QuantReLU count
- remaining float Conv2d
- remaining standalone float ReLU
- remaining SiLU

를 확인했습니다.

### Mixed-precision bit-width map

final W4 + selective A4/A8 model에서는 expected bit-width policy와 실제 module configuration을 비교했습니다.

```text
expected A8 set == actual A8 set
missing == 0
extra == 0
all convolution weights == W4
```

### Integer export audit

integer artifact 생성 후:

- weight reconstruction
- scale approximation
- bias conversion
- clipping/saturation
- rounding bound
- scale-source binding

을 검사했습니다.

### End-to-end acceptance

local parameter error가 허용 범위여도 full detection accuracy가 크게 감소하면 reject했습니다.

이 때문에 integer export는 parameter-level test와 dataset-level test를 모두 통과해야 합니다.

## Same-loader full test

최종 software-to-integer 비교는 evaluator 차이를 제거하기 위해 두 모델을 동일한 fixed 640×640 loader에서 새로 평가했습니다.

- images: 4,952
- instances: 12,032
- reference mAP@0.5:0.95: 55.84%
- standalone integer mAP@0.5:0.95: 55.40%
- difference: -0.439%p

## Save / reload gate

standalone integer reference는 저장 후 다른 실행 환경에서 다시 load할 수 있는 artifact로 저장하고 다음을 재확인했습니다.

- source YOLO object가 포함되지 않음
- Brevitas object가 포함되지 않음
- model type과 metadata 일치
- fixed input forward 성공
- prediction shape 일치
- multi-scale detection-grid shape 일치

이를 통해 notebook 실행 중 우연히 남아 있는 Python object에 의존하지 않는지 확인했습니다.

## Relation to RTL verification

software verification의 마지막 output은 일반 PyTorch prediction이 아니라 **RTL arithmetic contract를 적용한 integer golden**입니다.

```text
QAT checkpoint
    ↓
validated integer export
    ↓
standalone integer reference
    ↓
layer / output golden
    ↓
SystemVerilog scoreboard
```

RTL regression의 mismatch 0은 이 정의된 numeric contract 안에서 RTL이 software integer reference를 정확히 재현했다는 의미입니다.

전체 RTL regression 결과는 [Verification Strategy](../docs/03_VERIFICATION_STRATEGY.md)에서 별도로 관리합니다.
