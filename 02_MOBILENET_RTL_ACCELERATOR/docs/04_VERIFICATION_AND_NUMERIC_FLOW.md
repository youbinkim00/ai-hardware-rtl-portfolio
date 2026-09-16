# Verification and Numeric Flow

## Verification chain

MobileNetV1 case는 다음 단계로 correctness를 확인합니다.

```text
FP32 pretrained model
        ↓
INT8 QAT
        ↓
Fully Quantized INT8 model
        ↓
Integer parameter export
        ↓
Layer-wise integer reference
        ↓
RTL / FPGA output
        ↓
PYNQ classification result
```

## Numeric checks

- activation scale / zero-point
- per-channel weight scale
- INT8 weight
- INT32 bias
- requant multiplier / shift
- layer output integer value

## System checks

ZCU102 PYNQ demo에서는 다음 범위를 확인합니다.

- overlay load
- DMA transfer
- accelerator control
- FPGA inference completion
- accelerator output / reference consistency
- classification result display

## Acceptance boundary

Software CPU/GPU timing, RTL accelerator FPS, PYNQ application latency는 서로 다른 measurement boundary로 관리합니다.
