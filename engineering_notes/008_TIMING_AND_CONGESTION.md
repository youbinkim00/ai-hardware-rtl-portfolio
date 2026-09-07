# 008 — Distinguishing Timing Failure from Routing Failure

## Different failure classes

```text
Routing error/unrouted/overlap > 0
    → implementation legality problem

Routing legal, WNS < 0
    → setup timing problem

WHS < 0
    → hold timing problem
```

중간 routing iteration의 overlap 수가 0이 아니라고 최종 routing failure로 단정할 수 없습니다. 최종 route status의 failed/unrouted/overlap과 timing summary를 함께 확인해야 합니다.

## Path decomposition

Critical path는 다음을 분리해 봅니다.

- Logic delay와 logic levels
- Routing delay 비중
- Source/destination clock region
- High-fanout control signal
- Wide bus의 CE/reset dependency
- DSP/BRAM/URAM fixed-column crossing

Routing delay 비중이 크면 무조건 pipeline을 추가하기 전에 control fanout, physical span, unnecessary CE dependency와 hierarchy boundary를 확인합니다.

## Change discipline

- Legal-route baseline 보존
- 한 번에 하나의 원인만 수정
- OOC regeneration 확인
- Functional smoke 후 implementation
- 개선되지 않으면 원복 가능한 commit/DCP 유지
- Seed/strategy 차이를 RTL 개선으로 오해하지 않음

