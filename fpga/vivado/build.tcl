cd [file dirname [info script]]

set part $::env(VIVADO_PART)

create_project int8_nn_accelerator ./vivado_project -part $part -force

add_files top.sv

add_files ../../rtl/matrix_layer.sv
add_files ../../rtl/dot_product.sv
add_files ../../rtl/multiplier.sv
add_files ../../rtl/uart_tx.sv
add_files constraints.xdc

set_property top top [current_fileset]

launch_runs synth_1 -jobs 4
wait_on_run synth_1

launch_runs impl_1 -to_step route_design -jobs 4
wait_on_run impl_1

file mkdir ../../reports/vivado

open_run impl_1

report_utilization -file ../../reports/vivado/vivado_utilization.rpt
report_timing_summary -file ../../reports/vivado/vivado_timing.rpt
