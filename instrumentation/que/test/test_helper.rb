# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

require 'opentelemetry/sdk'
require 'opentelemetry-test-helpers'

require 'minitest/autorun'

require_relative '../lib/opentelemetry-instrumentation-que'

# global opentelemetry-sdk setup:
EXPORTER = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
span_processor = OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(EXPORTER)

require 'que'

class TestJobSync < Que::Job
  self.run_synchronously = true
end

class TestJobAsync < Que::Job
end

class JobThatFails < Que::Job
  def run
    raise 'oh no'
  end
end

OpenTelemetry::SDK.configure do |c|
  c.add_span_processor span_processor
end

def prepare_que
  require 'active_record'
  ActiveRecord::Base.establish_connection(
    adapter: 'postgresql',
    host: ENV.fetch('TEST_POSTGRES_HOST', '127.0.0.1'),
    port: ENV.fetch('TEST_POSTGRES_PORT', '5432'),
    user: ENV.fetch('TEST_POSTGRES_USER', 'postgres'),
    database: database_name,
    password: ENV.fetch('TEST_POSTGRES_PASSWORD', 'postgres')
  )

  # Que 1.2 and 2.2 use different migration versions and in order to
  # run both tests in the same database, we need to clean up previous
  # tables and functions. Easiest way is to drop and recreate public schema.
  ActiveRecord::Base.connection.execute('DROP SCHEMA public CASCADE')
  ActiveRecord::Base.connection.execute('CREATE SCHEMA public')

  Que.connection = ActiveRecord

  if que_version >= Gem::Version.new('2.1.0')
    Que.migrate!(version: 7)
  else
    Que.migrate!(version: 4)
  end
end

def database_name
  ENV.fetch('TEST_POSTGRES_DB', 'postgres')
end

def que_version
  Gem.loaded_specs['que'].version
end
