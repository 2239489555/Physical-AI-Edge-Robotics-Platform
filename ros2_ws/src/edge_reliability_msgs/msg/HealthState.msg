# Coarse health state derived from pipeline and system metrics.

uint8 HEALTHY=0
uint8 WARNING=1
uint8 UNHEALTHY=2

std_msgs/Header header
uint8 state
string reason
string[] active_rules
