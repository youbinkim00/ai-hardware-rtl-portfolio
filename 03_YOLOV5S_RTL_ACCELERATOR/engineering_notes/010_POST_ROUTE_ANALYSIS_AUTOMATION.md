# Post-Route Analysis Automation

## 1. Problem

FPGA implementation 문제를 분석할 때 `report_timing_summary`나 `report_power` 하나만 보는 것으로는 원인을 충분히 설명하기 어렵습니다.

같은 WNS라도 원인은 다음과 같이 다를 수 있습니다.

- logic depth
- routing delay
- high-fanout control
- placement / congestion
- clock relationship
- unconstrained path

Power도 total watt만 비교하면 activity source, SAIF coverage, operating condition 또는 implementation state 차이를 RTL 효과로 잘못 해석할 수 있습니다.

## 2. Approach

이 프로젝트에서는 post-route 상태를 세 관점으로 분리해 Tcl로 자동 수집합니다.

### Timing audit

- route status
- methodology / `check_timing`
- timing summary
- setup / hold violation paths
- high-fanout timing과 clock-region spread
- congestion / hierarchical utilization
- QoR assessment
- clock interaction / CDC
- timing-oriented design analysis

### Route / congestion audit

- full route status
- congestion level 3+ / 5+
- hierarchical utilization
- post-route DRC
- methodology
- hierarchical complexity
- high-fanout nets
- unrouted / partial / gap / conflict 등 problem-net class
- route Boolean status

### Power audit

- exact implementation state / clock / operating condition
- IMPLEMENTED / SAIF / VECTORLESS activity mode
- full propagated power와 no-propagation power 비교
- hierarchy power
- input / resource switching activity
- power optimization result
- utilization / clock utilization
- high-fanout context

## 3. Reproducible output

각 script는 개별 `.rpt` 외에 다음 bundle을 생성합니다.

```text
98_TIMING_ANALYSIS_BUNDLE.rpt
98_ROUTE_ANALYSIS_BUNDLE.rpt
98_POWER_ANALYSIS_BUNDLE.rpt
```

그리고 `99_report_generation_status.log`를 통해 일부 report command가 지원되지 않거나 실패하더라도 나머지 분석이 계속 진행되도록 구성했습니다.

## 4. Engineering use

이 automation의 목적은 report 개수를 늘리는 것이 아니라 **RTL 수정 전후를 같은 관점에서 비교**하는 것입니다.

```text
Baseline implementation
        ↓
Timing / Route / Power audit
        ↓
RTL or constraint change
        ↓
Implementation
        ↓
Same audit configuration
        ↓
Compare WNS · congestion · fanout · resource · power
```

한 지표가 개선돼도 기능, timing, routing 또는 power의 다른 지표가 악화되면 변경을 바로 채택하지 않습니다.

## 5. Power interpretation boundary

Power 비교에서는 특히 다음을 동일하게 유지합니다.

- FPGA part
- implementation state
- clock
- activity mode
- SAIF workload / simulation window
- process / temperature / airflow / heatsink condition

`full propagated power`와 `no-propagation power`의 차이가 크면, power estimate의 상당 부분이 direct activity annotation보다 vectorless propagation에 의존하고 있음을 먼저 확인합니다.

## 6. Public example

실제 reusable Tcl은 다음 경로에 공개합니다.

- [`vivado_postroute_timing_audit.tcl`](../public_examples/vivado_postroute_analysis/vivado_postroute_timing_audit.tcl)
- [`vivado_route_congestion_audit.tcl`](../public_examples/vivado_postroute_analysis/vivado_route_congestion_audit.tcl)
- [`vivado_postroute_power_audit.tcl`](../public_examples/vivado_postroute_analysis/vivado_postroute_power_audit.tcl)

실제 generated raw report는 내부 hierarchy와 net/cell name을 포함할 수 있으므로 public repository에는 포함하지 않습니다.

## 7. Engineering lesson

Implementation debugging은 단일 숫자의 개선이 아니라 **design state → timing → route → activity → power**를 같은 조건에서 반복 측정하고, 변화의 원인을 추적할 수 있어야 재현 가능한 engineering process가 됩니다.
