# AXI VIP Verification

## Purpose

Core의 numeric correctness와 AXI wrapper의 protocol correctness는 서로 다른 문제입니다. AXI VIP 단계에서는 NPU 내부 구현을 black box로 두고 다음 경계를 검증했습니다.

- AXI4-Lite control register transaction
- AXI4-Stream MM2S input delivery
- AXI4-Stream S2MM output collection
- Backpressure 중 payload stability
- Packet boundary와 `TKEEP/TLAST`

## Stress scenarios

| Scenario | 검증 목적 |
|---|---|
| MM2S input gap | 입력이 연속적이지 않아도 내부 상태가 깨지지 않는지 확인 |
| S2MM backpressure | `TREADY=0` 동안 `TDATA/TKEEP/TLAST`가 유지되는지 확인 |
| AXI-Lite channel skew | AW와 W channel이 다른 cycle에 도착해도 write가 정확한지 확인 |
| Output count check | 누락·중복 beat 검출 |
| TLAST check | 마지막 packet 위치 검증 |

검증 실행에서는 input gap 3,729 cycle과 output stall 18,200 cycle을 발생시켰고, 33,600 output beat의 data 및 handshake metadata를 golden과 비교했습니다.

## Evidence planned for publication

- AXI VIP Block Design 캡처
- `TVALID/TREADY` stall 구간을 표시한 waveform
- `TDATA/TKEEP/TLAST` stability annotation
- 최종 PASS/FAIL console summary

NPU 내부 RTL과 논문용 architecture는 포함하지 않습니다.

