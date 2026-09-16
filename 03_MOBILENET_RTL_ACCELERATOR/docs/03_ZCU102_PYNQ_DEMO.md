# ZCU102 AXI / DMA / PYNQ Classification Demo

[← MobileNetV1 overview](../README.md)

## Actual Vivado system integration

<p align="center">
  <img src="../../assets/evidence/mobilenet_zcu102_block_design.png" alt="MobileNetV1 ZCU102 Vivado Block Design with PS, AXI interface, AXI DMA, FIFO and custom MobileNetV1 accelerator" width="1150">
</p>

Source portfolio의 system integration figure는 다음 boundary를 보여줍니다.

```text
PYNQ / PS application
       │
       ├─ AXI4-Lite control
       │
       └─ DDR buffers
              ↕
           AXI DMA
        MM2S / S2MM
              ↕
             FIFO
              ↕
     MobileNetV1 custom IP
```

### Interface roles

- AXI4-Lite: accelerator control / register access
- AXI4-Stream: payload transfer
- AXI DMA: DDR ↔ PL stream conversion
- FIFO: input/output decoupling
- PS: overlay load, buffer/control and application flow

## PYNQ software-hardware boundary

<p align="center">
  <img src="../../assets/evidence/mobilenet_pynq_sw_hw_system.png" alt="PYNQ software hardware integration with Python Linux software, AXI DMA and PL custom accelerator" width="650">
</p>

PYNQ 환경에서는 Python/Linux application이 PS에서 동작하고, AXI/DMA를 통해 PL custom accelerator와 연결됩니다.

## Demo verification

Source portfolio page 10에는 ZCU102 PYNQ classification demo가 구현·검증 완료된 것으로 기록되어 있습니다.

검증 범위:

- PYNQ overlay load
- PL accelerator control
- image input transfer
- FPGA inference
- accelerator output과 reference result 비교
- classification result output까지 end-to-end application 연결

제공된 PDF에는 MobileNet demo의 별도 board/monitor photograph가 포함되어 있지 않아, public repository에서는 실제 Vivado Block Design과 PYNQ integration figure를 system evidence로 사용합니다. 존재하지 않는 demo photograph를 새로 생성하지 않습니다.

## Publication boundary

MobileNet manuscript의 proposed compute architecture, line-buffer, memory hierarchy, layer-adaptive parallelism, pipeline timing figure는 이 문서에 포함하지 않습니다.
