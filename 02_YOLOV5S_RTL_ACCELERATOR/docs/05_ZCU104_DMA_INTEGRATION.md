# ZCU104 AXI DMA Integration

## Actual ZCU104 Block Design

<p align="center">
  <img src="../../assets/evidence/zcu104_axi_dma_block_design.png" alt="Vivado ZCU104 block design connecting Zynq UltraScale+ MPSoC, SmartConnect, AXI DMA, AXI4-Stream FIFO, IRQ concat, reset logic, and the YOLOv5s RTL accelerator" width="1250">
</p>
<p align="center"><sub>현재 ZCU104 통합에 사용한 실제 Vivado Block Design. Custom YOLOv5s core는 외부 AXI interface만 보이고 내부 microarchitecture는 공개하지 않습니다.</sub></p>

이 그림은 개념적으로 다시 그린 AXI diagram이 아니라 실제 PS–PL integration 구조를 보여줍니다. 주요 데이터/제어 경계는 다음과 같습니다.

```text
PYNQ / PS software
  ├─ AXI4-Lite → SmartConnect → NPU / DMA control
  ├─ DDR input / parameter buffer
  └─ DDR output buffer
             ↕
          AXI DMA
     MM2S         S2MM
       │           ▲
       ▼           │
  Custom YOLOv5s NPU
       │
       ▼
 AXI4-Stream FIFO
```

## Interface roles

- `M_AXI_HPM0_FPD` 계열은 PS가 PL control register에 접근하는 control path에 사용
- SmartConnect는 AXI4-Lite control access를 NPU와 DMA에 분배
- DMA MM2S는 DDR payload를 AXI4-Stream input으로 변환
- NPU `S_AXIS_MM2S`는 input stream을 수신
- NPU `M_AXIS_S2MM`는 detection output stream을 전송
- AXI4-Stream FIFO는 output side의 decoupling/backpressure boundary를 제공
- DMA S2MM은 output stream을 DDR에 기록
- `irq_concat`는 NPU/DMA interrupt를 PS interrupt input으로 집계
- `proc_sys_reset` 계열 reset은 PL clock domain에 동기화된 reset을 배포

## Integration verification

Core와 AXI VIP에서 확인한 조건을 실제 DMA/SmartConnect/FIFO 통합 환경에서도 유지해야 합니다.

- Reset 및 clock domain 연결
- Address map과 register access
- DMA length와 NPU expected count 일치
- Input completion, layer request와 parameter supply 순서
- Output FIFO backpressure
- Final TLAST와 DMA completion
- Frame 간 상태 초기화 및 buffer ownership
- NPU/DMA interrupt propagation

## Clocking note

Block Design의 instance 이름에 과거 주파수를 암시하는 문자열이 남아 있을 수 있으므로 instance name을 주파수 근거로 사용하지 않습니다. 실제 clock target은 PS `pl_clk0` 설정과 propagated clock metadata, 이후 synthesized/implemented timing report로 검증합니다.

## Deployment status

ZCU104용 PS runtime에는 다음 구조를 준비했습니다.

- 정적 descriptor/payload와 frame별 feature 영역 분리
- physically contiguous DMA buffer의 다중 slot 운용
- `S2MM → accelerator arm → MM2S` 시작 순서
- capture/preprocess, serialized PL inference, postprocess/display의 bounded pipeline
- frame ID와 buffer ownership을 이용한 stale-frame drop 및 overwrite 방지
- preprocessing, DMA/PL, postprocessing, display와 end-to-end latency의 분리 계측

현재 저장소에는 matching `.bit`/`.hwh`와 board 측정 로그를 공개하지 않습니다. 따라서 continuous-video demo와 FPS는 해당 artifact pair로 replay·single-frame·continuous-frame 검증을 모두 통과한 뒤 완료 상태로 갱신합니다.
