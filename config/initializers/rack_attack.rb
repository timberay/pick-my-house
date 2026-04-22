class Rack::Attack
  throttle("writes_per_ip", limit: 60, period: 1.minute) do |req|
    req.ip if req.post? || req.patch? || req.put? || req.delete?
  end

  self.throttled_responder = lambda do |request|
    [ 429, { "Content-Type" => "text/plain" }, [ "잠시 후 다시 시도해 주세요." ] ]
  end
end

# Enable only in production by default; tests flip the switch per-test.
Rack::Attack.enabled = Rails.env.production?
