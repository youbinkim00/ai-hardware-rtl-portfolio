# Engineering Notes

이 디렉터리는 프로젝트 전체 RTL을 공개하지 않고도 FPGA/RTL 실무에서 얻은 세부 지식을 정리하는 짧은 기술 노트 모음입니다.

## Planned notes

| No. | 주제 | 핵심 내용 |
|---:|---|---|
| 001 | AXI VALID/READY | Stall 시 payload stability와 transfer 조건 |
| 002 | AXI DMA MM2S/S2MM | DDR, memory-mapped AXI와 stream의 관계 |
| 003 | BRAM IP | TDP/SDP, output register, read latency와 enable |
| 004 | URAM IP | Width/depth mapping, cascade와 latency |
| 005 | BRAM→URAM migration | 기능을 유지하며 memory primitive를 변경하는 검증법 |
| 006 | Vivado OOC | Module reference와 generated target 관리 |
| 007 | Incremental DCP | Legal route 보존과 수정 logic 반영 확인 |
| 008 | Congestion debugging | Overlap, failed net, high fanout과 timing을 구분하는 법 |

## Article template

각 글은 다음 형식을 사용합니다.

```text
1. Problem
2. Concept
3. Minimal public example
4. Common failure modes
5. Verification checklist
6. Engineering lesson
```

실제 NPU의 상세 memory organization, address mapping과 scheduling rule은 일반화한 예제로 대체합니다.

