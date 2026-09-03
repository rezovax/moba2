use std::time::Duration;

use match_core::{MovementIntent, TICKS_PER_SECOND, UNITS_PER_METER, WorldConfig};
use match_runtime::MatchRuntime;

fn main() {
    let mut runtime = MatchRuntime::new(WorldConfig::concept_demo()).expect("valid concept world");
    run_for_seconds(&mut runtime, 65, MovementIntent::RIGHT);

    let current = runtime.current();
    let at_one_minute_five = runtime
        .snapshot_at_time(Duration::from_secs(65))
        .expect("state at 1:05 must be recorded");

    println!(
        "SIMULATOR_CONCEPT_PASS time=1:05 tick={} position=({:.3}, {:.3})m history_states={}",
        at_one_minute_five.tick,
        current.character_position.x as f64 / UNITS_PER_METER as f64,
        current.character_position.y as f64 / UNITS_PER_METER as f64,
        runtime.history_len(),
    );
}

fn run_for_seconds(runtime: &mut MatchRuntime, seconds: u64, movement: MovementIntent) {
    for _ in 0..(seconds * TICKS_PER_SECOND) {
        runtime.advance(movement).expect("concept match is running");
    }
}
