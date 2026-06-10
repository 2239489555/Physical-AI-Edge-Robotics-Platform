# Raw sensor-like sample used by fake, replayed, and future adapter inputs.

uint8 STATUS_OK=0
uint8 STATUS_WARN=1
uint8 STATUS_ERROR=2

std_msgs/Header header
uint64 sequence_id
string sensor_id
float64 value
uint8 status
string status_detail
