# ZCU102 AXI / PYNQ Integration

## System boundary

MobileNetV1 accelerator는 ZCU102에서 PS와 PL을 AXI로 연결해 classification application까지 구성했습니다.

```text
PYNQ / PS application
        ↓
AXI4-Lite control
        ↓
DDR buffer ↔ AXI DMA
        ↓
AXI4-Stream / FIFO
        ↓
MobileNetV1 RTL accelerator
```

## Integration tasks

- custom accelerator의 AXI4-Stream / AXI4-Lite interface 연결
- AXI DMA 기반 DDR–PL transfer
- FIFO를 이용한 input/output decoupling
- PYNQ overlay load
- PS-side accelerator control
- accelerator output과 reference result 비교
- image input → FPGA inference → classification result까지 application flow 연결

## Engineering point

RTL core가 단독으로 동작하는 것과 실제 SoC application에서 안정적으로 동작하는 것은 다른 문제입니다.

Board integration에서는 다음 경계를 별도로 확인합니다.

- control register access
- DMA buffer ownership
- stream completion
- input/output count
- reset / re-arm
- software result와 accelerator result consistency
