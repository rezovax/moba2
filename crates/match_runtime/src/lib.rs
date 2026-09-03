//! Stateful match lifecycle and complete state history around [`match_core::World`].

use std::time::Duration;

use match_core::{
    MovementIntent, TICKS_PER_SECOND, World, WorldConfig, WorldConfigError, WorldSnapshot,
};

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum StopReason {
    Administrative,
    AllPlayersLeft,
    TestCompleted,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum MatchStatus {
    Running,
    Stopped(StopReason),
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum AdvanceError {
    MatchStopped(StopReason),
}

#[derive(Clone, Debug)]
pub struct MatchRuntime {
    world: World,
    history: Vec<WorldSnapshot>,
    status: MatchStatus,
}

impl MatchRuntime {
    pub fn new(config: WorldConfig) -> Result<Self, WorldConfigError> {
        let world = World::new(config)?;
        Ok(Self {
            history: vec![world.snapshot()],
            world,
            status: MatchStatus::Running,
        })
    }

    #[must_use]
    pub const fn status(&self) -> MatchStatus {
        self.status
    }

    #[must_use]
    pub const fn current(&self) -> WorldSnapshot {
        self.world.snapshot()
    }

    #[must_use]
    pub fn game_time(&self) -> Duration {
        tick_to_duration(self.current().tick)
    }

    #[must_use]
    pub fn history_len(&self) -> usize {
        self.history.len()
    }

    pub fn advance(&mut self, movement: MovementIntent) -> Result<WorldSnapshot, AdvanceError> {
        if let MatchStatus::Stopped(reason) = self.status {
            return Err(AdvanceError::MatchStopped(reason));
        }
        let snapshot = self.world.advance(movement);
        self.history.push(snapshot);
        Ok(snapshot)
    }

    pub fn stop(&mut self, reason: StopReason) {
        if self.status == MatchStatus::Running {
            self.status = MatchStatus::Stopped(reason);
        }
    }

    #[must_use]
    pub fn snapshot_at_tick(&self, tick: u64) -> Option<WorldSnapshot> {
        usize::try_from(tick)
            .ok()
            .and_then(|index| self.history.get(index))
            .copied()
    }

    #[must_use]
    pub fn snapshot_at_time(&self, game_time: Duration) -> Option<WorldSnapshot> {
        self.snapshot_at_tick(duration_to_tick(game_time))
    }
}

#[must_use]
pub fn tick_to_duration(tick: u64) -> Duration {
    Duration::from_nanos(tick.saturating_mul(1_000_000_000) / TICKS_PER_SECOND)
}

#[must_use]
pub fn duration_to_tick(duration: Duration) -> u64 {
    let ticks = duration.as_nanos() * u128::from(TICKS_PER_SECOND) / 1_000_000_000;
    u64::try_from(ticks).unwrap_or(u64::MAX)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn keeps_every_calculated_world_state() {
        let mut runtime = MatchRuntime::new(WorldConfig::concept_demo()).expect("valid runtime");
        for _ in 0..(65 * TICKS_PER_SECOND) {
            runtime
                .advance(MovementIntent::IDLE)
                .expect("running match");
        }
        let at_one_minute_five = runtime
            .snapshot_at_time(Duration::from_secs(65))
            .expect("recorded state at 1:05");
        assert_eq!(at_one_minute_five.tick, 65 * TICKS_PER_SECOND);
        assert_eq!(runtime.history_len() as u64, at_one_minute_five.tick + 1);
    }

    #[test]
    fn equal_inputs_produce_equal_history() {
        let mut first = MatchRuntime::new(WorldConfig::concept_demo()).expect("valid runtime");
        let mut second = MatchRuntime::new(WorldConfig::concept_demo()).expect("valid runtime");
        let input = MovementIntent::new(12_000, -24_000);
        for _ in 0..300 {
            first.advance(input).expect("running match");
            second.advance(input).expect("running match");
        }
        assert_eq!(first.current(), second.current());
    }

    #[test]
    fn stopped_match_does_not_advance() {
        let mut runtime = MatchRuntime::new(WorldConfig::concept_demo()).expect("valid runtime");
        runtime.stop(StopReason::TestCompleted);
        assert_eq!(
            runtime.advance(MovementIntent::RIGHT),
            Err(AdvanceError::MatchStopped(StopReason::TestCompleted))
        );
    }
}
