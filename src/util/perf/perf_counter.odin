package perf

import "core:time"

// Measure input-to-display latency.
//
// Measurement should be started by perf_counter_frame_begin just after receiving
// any input, and stopped by perf_counter_frame_end after the rendering is completed.
// Any unwanted frame (eg. input that do not change the screen) might be discarded
// by perf_counter_frame_discard.

Counter :: struct {
    stopwatch: time.Stopwatch,
    frame_count: u64,
}

counter_reset :: proc (perf_counter: ^Counter) {
    time.stopwatch_reset(&perf_counter.stopwatch)
    perf_counter.frame_count = 0
}

counter_frame_begin :: proc (perf_counter: ^Counter) {
    time.stopwatch_start(&perf_counter.stopwatch)
}

counter_frame_end :: proc (perf_counter: ^Counter) {
    if perf_counter.stopwatch.running {
        perf_counter.frame_count += 1
        time.stopwatch_stop(&perf_counter.stopwatch)
    }
}

counter_frame_discard :: proc (perf_counter: ^Counter) {
    time.stopwatch_reset(&perf_counter.stopwatch)
}

counter_frame_time_average :: proc (perf_counter: ^Counter) -> time.Duration {
    acc := time.stopwatch_duration(perf_counter.stopwatch)
    return acc / time.Duration(perf_counter.frame_count)
}
