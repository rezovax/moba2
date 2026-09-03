use std::time::Duration;

use godot::classes::{IRefCounted, RefCounted};
use godot::prelude::*;
use match_core::{MovementIntent, UNITS_PER_METER, WorldConfig, WorldSnapshot};
use match_runtime::MatchRuntime;

struct MobaGodotExtension;

#[gdextension]
unsafe impl ExtensionLibrary for MobaGodotExtension {}

#[derive(GodotClass)]
#[class(base=RefCounted)]
struct PredictionWorld {
    runtime: MatchRuntime,
    base: Base<RefCounted>,
}

#[godot_api]
impl IRefCounted for PredictionWorld {
    fn init(base: Base<RefCounted>) -> Self {
        Self {
            runtime: create_runtime(),
            base,
        }
    }
}

#[godot_api]
impl PredictionWorld {
    #[func]
    fn advance(&mut self, direction: Vector2) -> Vector2 {
        let movement = movement_from_vector(direction);
        let snapshot = self
            .runtime
            .advance(movement)
            .expect("prediction world must remain running");
        position_in_meters(snapshot)
    }

    #[func]
    fn current_position(&self) -> Vector2 {
        position_in_meters(self.runtime.current())
    }

    #[func]
    fn current_tick(&self) -> i64 {
        i64::try_from(self.runtime.current().tick).unwrap_or(i64::MAX)
    }

    #[func]
    fn game_time_seconds(&self) -> f64 {
        self.runtime.game_time().as_secs_f64()
    }

    #[func]
    fn position_at_time(&self, seconds: f64) -> Vector2 {
        let safe_seconds = seconds.max(0.0);
        self.runtime
            .snapshot_at_time(Duration::from_secs_f64(safe_seconds))
            .map_or_else(|| Vector2::ZERO, position_in_meters)
    }

    #[func]
    fn reset(&mut self) {
        self.runtime = create_runtime();
    }
}

fn create_runtime() -> MatchRuntime {
    MatchRuntime::new(WorldConfig::concept_demo()).expect("concept world configuration is valid")
}

fn movement_from_vector(direction: Vector2) -> MovementIntent {
    let limited = direction.limit_length(Some(1.0));
    MovementIntent::new(quantize_axis(limited.x), quantize_axis(limited.y))
}

fn quantize_axis(value: f32) -> i16 {
    let scaled = value.clamp(-1.0, 1.0) * f32::from(i16::MAX);
    scaled.round() as i16
}

fn position_in_meters(snapshot: WorldSnapshot) -> Vector2 {
    Vector2::new(
        snapshot.character_position.x as f32 / UNITS_PER_METER as f32,
        snapshot.character_position.y as f32 / UNITS_PER_METER as f32,
    )
}
