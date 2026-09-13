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

ZCU104용 PS runtime에는 다음 구조를 준비했습니다.

- 정적 descriptor/payload와 frame별 feature 영역 분리
- physically contiguous DMA buffer의 다중 slot 운용
- `S2MM → accelerator arm → MM2S` 시작 순서
- capture/preprocess, serialized PL inference, postprocess/display의 bounded pipeline
- frame ID와 buffer ownership을 이용한 stale-frame drop 및 overwrite 방지
- preprocessing, DMA/PL, postprocessing, display와 end-to-end latency의 분리 계측

현재 저장소에는 matching `.bit`/`.hwh`와 board 측정 로그를 공개하지 않습니다. 따라서 continuous-video demo와 FPS는 해당 artifact pair로 replay·단일 frame·연속 frame 검증을 모두 통과한 뒤 완료 상태로 갱신합니다.

