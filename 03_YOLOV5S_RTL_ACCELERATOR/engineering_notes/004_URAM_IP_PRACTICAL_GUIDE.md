# 004 — UltraRAM Practical Guide

## When URAM is attractive

UltraRAM은 큰·깊은 on-chip storage에 유리하며 BRAM pressure를 낮출 수 있습니다. 그러나 BRAM의 drop-in replacement로 가정하면 latency, port behavior와 packing 차이 때문에 기능 오류가 발생할 수 있습니다.

## Key checks

- Device에 필요한 URAM 개수가 실제로 존재하는가?
- Logical width/depth가 URAM primitive에 어떻게 분할·cascade되는가?
- 두 port의 clock과 operation mode가 설계 access pattern과 맞는가?
- Output pipeline을 포함한 read latency가 기존 controller와 동일한가?
- Collision behavior가 기존 BRAM contract와 호환되는가?
- Placement가 compute region과 지나치게 멀어 routing 병목을 만들지 않는가?

## Power interpretation

URAM 전환이 항상 total power를 낮추는 것은 아닙니다. Array access, clock network, cascade, surrounding register와 routing activity를 함께 봐야 합니다. 정확한 비교에는 동일 workload와 동일 observation window의 activity가 필요합니다.

## Evidence

Synthesis 후 단순히 RTL module 이름만 확인하지 않고 utilization hierarchy에서 실제 URAM primitive 수와 BRAM 감소량을 확인합니다. 기능 검증에서는 첫 read보다 layer boundary, 마지막 word와 port-switching cycle을 우선 확인합니다.

