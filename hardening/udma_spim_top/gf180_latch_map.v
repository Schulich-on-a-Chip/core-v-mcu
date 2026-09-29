// Map Yosys generic level-sensitive latches to GF180 7-track cells.
//
// udma_spim_top uses three intentional latches inside glitch-free clock gates.
// The GF180 Ciel package does not currently provide LibreLane's expected
// latch_map.v, so keep this hardening-only mapping next to the design config.

module \$_DLATCH_P_ (E, D, Q);
  input  E;
  input  D;
  output Q;

  gf180mcu_fd_sc_mcu7t5v0__latq_1 _TECHMAP_REPLACE_ (
    .D(D),
    .E(E),
    .Q(Q)
  );
endmodule

module \$_DLATCH_N_ (E, D, Q);
  input  E;
  input  D;
  output Q;

  wire enable_high;

  gf180mcu_fd_sc_mcu7t5v0__inv_1 enable_inverter (
    .I (E),
    .ZN(enable_high)
  );

  gf180mcu_fd_sc_mcu7t5v0__latq_1 _TECHMAP_REPLACE_ (
    .D(D),
    .E(enable_high),
    .Q(Q)
  );
endmodule
