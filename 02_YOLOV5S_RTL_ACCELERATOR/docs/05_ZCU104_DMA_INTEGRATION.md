# ZCU104 AXI DMA Integration

## System boundary

```text
PYNQ/PS software
  ├─ AXI4-Lite: NPU와 DMA 제어
  ├─ DDR input/parameter buffer
  └─ DDR output buffer
             ↕
          AXI DMA
     MM2S         S2MM
       │           ▲
       ▼           │
      Custom YOLOv5s NPU
```

## Interface roles

- AXI4-Lite는 시작, 상태, descriptor와 interrupt 관련 제어에 사용
- MM2S는 DDR의 input feature/weight/parameter payload를 AXI4-Stream으로 변환
- S2MM은 NPU의 streaming detection output을 DDR buffer에 기록
- `TVALID/TREADY` handshake가 각 stream beat의 실제 전송 시점을 결정

## Integration verification

Core와 AXI VIP에서 확인한 조건을 실제 DMA/SmartConnect/FIFO 통합 환경에서도 유지해야 합니다.

- Reset 및 clock domain 연결
- Address map과 register access
- DMA length와 NPU expected count 일치
- Input completion, layer request와 parameter supply 순서
- Output FIFO backpressure
- Final TLAST와 DMA completion
- Frame 간 상태 초기화 및 buffer ownership

## Deployment status

ZCU104 URAM 기반 설계의 simulation 및 physical implementation을 점검 중입니다. PYNQ video pipeline과 실제 board FPS는 측정 완료 후 공개하며 예상값을 결과처럼 사용하지 않습니다.

