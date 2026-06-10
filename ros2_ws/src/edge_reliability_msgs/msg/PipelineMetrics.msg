# Aggregated metrics derived from SensorSample traffic over a rolling window.

std_msgs/Header header
uint64 received_count
uint64 expected_count
uint64 dropped_count
uint64 out_of_order_count
float64 receive_rate_hz
float64 expected_rate_hz
float64 average_latency_ms
float64 p95_latency_ms
float64 p99_latency_ms
float64 drop_rate
