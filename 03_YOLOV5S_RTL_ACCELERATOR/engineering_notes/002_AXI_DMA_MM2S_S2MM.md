# 002 — AXI DMA: MM2S and S2MM

## Four different interface roles

| Interface | 역할 |
|---|---|
| `S_AXI_LITE` | PS가 DMA control/status register를 설정 |
| `M_AXI_MM2S` | DMA가 DDR에서 데이터를 읽는 memory-mapped master |
| `M_AXIS_MM2S` | 읽은 데이터를 NPU로 내보내는 stream master |
| `S_AXIS_S2MM` | NPU 출력을 받는 stream slave |
| `M_AXI_S2MM` | 받은 출력을 DDR에 쓰는 memory-mapped master |

MM2S와 S2MM은 방향을 나타내며, `AXI`와 `AXIS`는 protocol 종류를 나타냅니다.

```text
DDR --M_AXI_MM2S--> DMA --M_AXIS_MM2S--> NPU
DDR <--M_AXI_S2MM-- DMA <--S_AXIS_S2MM-- NPU
```

## Why DDR does not overflow the DMA

DDR read도 AXI memory-mapped channel의 handshake와 outstanding/burst control을 따릅니다. Stream downstream이 막히면 DMA 내부 buffer가 차고, DMA는 추가 DDR request 또는 response 수용 속도를 제한합니다. 모든 구간이 각자의 flow control을 갖기 때문에 단순히 DDR이 무한히 밀어 넣는 구조가 아닙니다.

## Software responsibility

PYNQ software는 physically contiguous buffer를 할당하고 DMA에 다음 정보를 설정합니다.

- Source/destination physical address
- Transfer length
- Start/control bit

`transfer()` API가 이 register programming을 감싸지만, 실제 hardware에서는 DMA control register에 주소와 길이를 기록합니다.

