# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/human_plus"

# Deterministic surrender waves in tests. The CLI keeps them random —
# letting go is not linear.
srand 42
