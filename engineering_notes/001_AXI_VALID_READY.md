# 001 — AXI4-Stream VALID/READY Handshake

## Transfer condition

AXI4-Stream beat는 rising edge에서 다음 조건이 동시에 참일 때만 전달됩니다.

```text
transfer = TVALID && TREADY
```

`TVALID=1`, `TREADY=0`은 전송 완료가 아닙니다. Master는 그동안 `TDATA`, `TKEEP`, `TLAST`를 변경하지 않아야 합니다.

## Common mistake

```systemverilog
if (m_axis_tvalid)
    m_axis_tdata <= next_data;  // TREADY=0이어도 변경될 수 있음
```

Backpressure에서 payload가 바뀌므로 protocol violation입니다. 상태와 counter는 handshake가 발생했을 때만 전진해야 합니다.

```systemverilog
wire axis_fire = m_axis_tvalid && m_axis_tready;

if (axis_fire) begin
    beat_count <= beat_count + 1'b1;
end
```

## Verification checklist

- Stall 동안 `TDATA/TKEEP/TLAST` stable
- `TVALID`은 handshake 전 임의로 내려가지 않음
- Counter는 `TVALID&&TREADY`에서만 증가
- 마지막 beat에만 `TLAST=1`
- Partial beat에서는 `TKEEP`이 유효 byte를 정확히 표시

공개용 assertion 예제는 [`axi_stream_stability_checker.sv`](../public_examples/axi_stream_stability_checker.sv)에 있습니다.

