<?php
// Generate shared rounding vectors from the AUTHORITATIVE side (PHP).
$vals = [
 0, 1, 0.5, 2.5, 3.5, -2.5, 10.999, 2.675, 1.005, 8.995, 0.125, 0.045,
 1.115, 1234.565, 0.1+0.2, 19.99, 59.97, 99.99, 0.01, 0.005, 0.004,
 12.345, 12.344, 999.995, 1000.005, -0.005, -10.999, 33.333, 66.666,
 7.775, 0.335, 2.345, 4.985, 150.125, 0.615, 1.045
];
$out = [];
foreach ($vals as $v) {
  $out[] = ['input' => $v, 'digits' => 2, 'expected' => round($v, 2)];
}
foreach ([0,1,3] as $d) {
  foreach ([10.999, 2.675, 1.005, 0.125, 1234.565] as $v) {
    $out[] = ['input' => $v, 'digits' => $d, 'expected' => round($v, $d)];
  }
}
echo json_encode(['_comment'=>'GENERATED FROM PHP round(). Server is authoritative. Do not hand-edit.','_source'=>'docs/money_rounding.md','vectors'=>$out], JSON_PRETTY_PRINT|JSON_PRESERVE_ZERO_FRACTION);
