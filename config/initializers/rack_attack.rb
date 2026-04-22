class Rack::Attack
  # Test env toggles enabled via teardown; for prod/dev it is always on.
  Rack::Attack.enabled = !Rails.env.test?

  # Throttle write endpoints per IP.
  throttle("write-endpoints per ip", limit: 10, period: 1.minute) do |req|
    req.ip if req.post? || req.patch? || req.put? || req.delete?
  end

  self.throttled_responder = ->(_env) {
    [ 429, { "Content-Type" => "text/html" }, [ "<h1>잠시 후 다시 시도해 주세요</h1>" ] ]
  }
end
