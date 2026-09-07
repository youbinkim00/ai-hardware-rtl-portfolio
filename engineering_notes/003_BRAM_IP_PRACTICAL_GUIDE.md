# 003 — BRAM IP Practical Guide

## First decisions

- Single Port, Simple Dual Port, True Dual Port 중 실제 access pattern 선택
- Logical width/depth와 physical BRAM packing 확인
- Read-first, write-first, no-change collision behavior 확인
- Output register 사용 여부와 총 read latency 고정
- Enable과 register clock-enable의 의미 구분

## Latency contract

Block Memory Generator의 output register를 활성화하면 Fmax는 좋아질 수 있지만 read data가 한 cycle 더 늦어집니다. Controller의 address, valid와 data는 반드시 동일한 pipeline depth를 가져야 합니다.

```text
cycle N   : EN=1, ADDR=A
cycle N+1 : BRAM internal read result
cycle N+2 : registered DOUT valid   // output register 사용 예
```

GUI 설정 이름만 기록하지 말고 testbench에서 observed latency를 assertion으로 고정하는 것이 안전합니다.

## Power-aware enable

사용하지 않는 cycle에 `EN=0`으로 두면 unnecessary memory access를 줄일 수 있습니다. 출력 register를 hold하는 것과 memory array access를 막는 것은 동일하지 않으므로 primitive/IP port별 enable 의미를 확인해야 합니다.

## Verification checklist

- Port별 read/write latency
- Same-address collision
- Reset 후 output state
- Enable=0에서 address/data behavior
- byte-write enable mapping
- Synthesis report의 BRAM inference/usage

