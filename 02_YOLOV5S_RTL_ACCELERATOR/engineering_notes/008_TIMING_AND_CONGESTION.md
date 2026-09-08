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

## Nominal constraint and implementation guard are different

200 MHz의 실제 요구조건은 5.000 ns입니다. 선택한 boundary endpoint만 4.800 ns로 조이는 것은 200 MHz를 완화하는 것이 아니라 0.200 ns의 추가 구현 여유를 요구하는 local overconstraint입니다.

- 4.800 ns guard는 AXI specification이 정한 값이 아님
- Guard 결과와 nominal 5.000 ns 결과를 분리해 보고
- Guard fail, nominal pass라면 200 MHz pass이지만 추가 margin은 미확보
- Endpoint selector가 비어 있지 않은지만 확인하지 않고 family별 count와 exception coverage 확인

`set_max_delay`의 잘못된 start/end object는 path segmentation을 만들 수 있습니다. Clock과 sequential `D/CE`처럼 유효한 object를 사용하고, critical warning 및 `report_exceptions -coverage/-ignored`를 확인합니다. 자세한 사례는 [Selective Wrapper Timing Guardband](009_SELECTIVE_WRAPPER_TIMING_GUARDBAND.md)를 참고하십시오.

## Change discipline

- Legal-route baseline 보존
- 한 번에 하나의 원인만 수정
- OOC regeneration 확인
- Functional smoke 후 implementation
- 개선되지 않으면 원복 가능한 commit/DCP 유지
- Seed/strategy 차이를 RTL 개선으로 오해하지 않음

## Official AMD references

- [UG906 — Router Initial Congestion Reporting](https://docs.amd.com/r/2023.1-English/ug906-vivado-design-analysis/Router-Initial-Congestion-Reporting)
- [UG903 — Maximum/minimum delay consequences](https://docs.amd.com/r/2023.1-English/ug903-vivado-using-constraints/Consequences-of-Setting-Maximum-Delay-or-Minimum-Delay-Constraints-on-a-Path)
- [UG903 — Path segmentation](https://docs.amd.com/r/2023.1-English/ug903-vivado-using-constraints/Path-Segmentation)
