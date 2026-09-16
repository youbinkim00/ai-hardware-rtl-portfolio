# Integer Export and Requantization

## Why export is necessary

PyTorch quantized layer가 내부적으로 사용하는 scale과 zero-point를 그대로 RTL에 전달할 수는 없습니다.  
RTL에서는 각 layer의 정수 계산 규칙을 명시적인 field와 parameter로 변환해야 합니다.

## Exported information

공개 가능한 범위에서 다음 정보를 추출합니다.

- INT8 weight
- per-channel weight scale
- input / output activation scale과 zero-point
- FP32 bias에서 변환한 INT32 bias
- layer별 requantization parameter

## Integer requantization

Convolution accumulation 이후 필요한 scale 관계는 개념적으로 다음과 같습니다.

```text
fused_scale = (input_scale × weight_scale) / output_scale
```

software에서는 이 값을 RTL에서 사용 가능한 정수 형태로 근사합니다.

```text
output ≈ accumulator × multiplier >> shift
```

따라서 floating-point scale을 그대로 사용하는 대신, **integer multiplier + shift** 형태로 바꾸고 근사 오차를 확인합니다.

## RTL-oriented artifacts

Notebook flow에서는 layer별로 다음 종류의 파일을 생성합니다.

```text
weight_int8/
bias_int32/
requant_a/
requant_b/
```

이 과정은 model quantization과 RTL fixed-point implementation 사이의 numeric contract 역할을 합니다.

## Disclosure boundary

실제 전체 weight/parameter payload와 논문용 상세 mapping은 공개하지 않습니다.  
이 문서는 **변환 원리와 검증 경계**만 설명합니다.
