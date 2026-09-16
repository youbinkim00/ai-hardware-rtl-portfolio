# Software–RTL Reference

## Purpose

QAT model과 RTL 사이에 바로 비교를 걸면 framework 내부 quantization 동작과 RTL arithmetic의 차이를 분리하기 어렵습니다.

그래서 MobileNetV1 case에서도 quantized model의 layer output을 기준으로, RTL 동작과 가까운 **integer reference path**를 별도로 구성합니다.

## Reference sequence

```text
quantized input
    ↓
INT8 weight
    ↓
INT32 accumulation
    ↓
integer bias
    ↓
multiplier / shift requantization
    ↓
uint8 / int8 activation
```

## Observability

Notebook에는 Stem과 각 MobileNet block의 DWC/PWC 경로를 따라 PyTorch INT8 reference와 비교할 수 있는 layer-level extraction / comparison code가 포함되어 있습니다.

이를 통해 다음 항목을 분리해 확인할 수 있습니다.

- input tensor quantization
- DWC/PWC weight packing
- INT32 accumulation
- bias scaling
- requantization
- layer output integer value

## Verification role

이 reference는 FPGA 결과를 단순 classification label만으로 확인하지 않고, **중간 layer의 정수 결과까지 추적할 수 있는 기준**을 제공합니다.

전체 golden vector는 공개하지 않으며, 공개 repository에는 검증 방법과 numeric rule만 남깁니다.
