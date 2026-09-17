# Vivado Post-Route Analysis Automation

Vivado implementation 결과를 GUI에서 개별적으로 확인하는 대신, **Timing / Routing / Power 상태를 같은 기준으로 반복 수집**하기 위한 Tcl toolset입니다.

이 스크립트들은 implementation을 새로 실행하거나 netlist를 수정하지 않습니다. 지정한 implementation run의 최신 checkpoint를 열고, 분석용 report를 생성합니다.

## Tools

| Script | Purpose | Main output |
|---|---|---|
| [`vivado_postroute_timing_audit.tcl`](vivado_postroute_timing_audit.tcl) | setup/hold, unconstrained timing, high-fanout, congestion, QoR, clock interaction, CDC | `98_TIMING_ANALYSIS_BUNDLE.rpt` |
| [`vivado_route_congestion_audit.tcl`](vivado_route_congestion_audit.tcl) | route legality, congestion, DRC, complexity, high-fanout, unrouted/problem-net classes | `98_ROUTE_ANALYSIS_BUNDLE.rpt` |
| [`vivado_postroute_power_audit.tcl`](vivado_postroute_power_audit.tcl) | power hierarchy, activity source/coverage, SAIF, operating conditions, utilization, high-fanout context | `98_POWER_ANALYSIS_BUNDLE.rpt` |

## Common configuration

세 스크립트 모두 상단에서 implementation run을 선택합니다.

```tcl
set IMPL_RUN_NAME "impl_1"
```

Timing과 Route script는 선택한 run을 열어 분석 report만 생성합니다.

Power script는 추가로 activity source를 선택합니다.

```tcl
set POWER_ACTIVITY_MODE "IMPLEMENTED"
# "IMPLEMENTED" / "SAIF" / "VECTORLESS"
```

SAIF mode에서는 `SAIF_FILE`과 필요 시 `SAIF_STRIP_PATH`를 지정합니다.

## Run

Vivado Tcl Console에서:

```tcl
source vivado_postroute_timing_audit.tcl
source vivado_route_congestion_audit.tcl
source vivado_postroute_power_audit.tcl
```

각 script는 해당 implementation run directory 아래에 별도 report folder를 생성합니다.

```text
<run>/
├─ timing_debug/
├─ route_congestion_check/
└─ power_debug/
```

## Why combined bundles?

개별 report 하나만 보면 원인을 잘못 해석하기 쉽습니다.

예를 들어 negative WNS는 logic depth뿐 아니라 routing, high fanout, congestion, clock relationship과 함께 확인해야 합니다. Power도 total watt만 보는 것이 아니라 activity source, SAIF coverage, operating condition과 hierarchy를 함께 확인해야 합니다.

그래서 각 script는 분석에 필요한 핵심 report를 `98_*_ANALYSIS_BUNDLE.rpt` 하나로 묶고, `99_report_generation_status.log`에 각 command의 성공/실패를 남깁니다.

## Before / after comparison

RTL 또는 implementation option을 변경한 전후 결과를 비교할 때는 다음 조건을 고정합니다.

- FPGA part
- clock constraints
- implementation stage
- report configuration
- power의 경우 activity workload/window와 operating condition

조건이 다르면 WNS, congestion level, power 차이를 RTL 변경 효과로 직접 해석하지 않습니다.

## Public disclosure boundary

이 repository에는 **재사용 가능한 Tcl automation만 공개**합니다.

실제 generated report는 hierarchy, cell/net name, local path와 implementation detail을 포함할 수 있으므로 그대로 공개하지 않습니다. 필요한 경우 민감 정보를 제거한 요약 결과만 문서에 사용합니다.

→ 분석 방법과 engineering rationale는 [Post-Route Analysis Automation](../../engineering_notes/010_POST_ROUTE_ANALYSIS_AUTOMATION.md)에 정리했습니다.
