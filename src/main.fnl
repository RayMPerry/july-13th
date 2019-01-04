;; -*- compile-command: "fennel --compile main.fnl > main.lua && love ." -*-

(local (lg lk le la)
       (values
        love.graphics
        love.keyboard
        love.event
        love.audio))

(local lume (require :lume))
(local flux (require :flux))

(local player { :x 32 :y 32 :radius 0 :opacity 1 :speed 100 })
(local ring { :radius 500 :opacity 1 })
(local gamestate { :status :STARTING :status-hooks [] })
(local gong (la.newSource "bowl.wav" :static))
(: gong :setVolume 0.8)

(fn start-reluctance []
    (: (flux.to player 5 { :x ring.x :y ring.y :opacity 1 }) :ease :cubicout))

(var reluctance (start-reluctance))

(fn register-callback [callback-type callback]
    (if callback-type
        (let [number-of-callbacks
              (# (. gamestate callback-type))
              message
              (..
               "Added callback #"
                (+ number-of-callbacks 1)
                " to '"
                callback-type
                "'.")]
          (table.insert (. gamestate callback-type) callback))
        (callback))
    (# (. gamestate callback-type)))

(fn unregister-callback [callback-type index]
    (if index
        (table.remove (. gamestate callback-type) index)
        (table.remove (. gamestate callback-type))))

(fn run-callbacks [list-of-callbacks]
    (each [key callback (pairs list-of-callbacks)]
          (when (= (type callback) :function)
            (callback))))

(fn set-gamestate-status [state]
    (set gamestate.status state)
    (run-callbacks gamestate.status-hooks))

(fn quit-game [] (set-gamestate-status :STOPPING))

(fn move-player [axis direction dt]
    (print axis direction dt)
    
    (: reluctance :stop)
    (let [[width height] [(lg.getDimensions)]]
      (local new-value (+ (. player axis) (* direction (* player.speed player.opacity) dt)))
      (when (not (= gamestate.status :COMPLETE))
        (tset player axis new-value))
      (when (or (< (+ player.x player.radius) 0)
                (< (+ player.y player.radius) 0)
                (> (- player.x player.radius) width)
                (> (- player.y player.radius) height))
        (set-gamestate-status :COMPLETE)))

    (set player.opacity
         (lume.clamp (- 1 (/ (- (lume.distance player.x player.y ring.x ring.y) ring.radius) (* ring.radius 1.15))) 0 1))

    (when (and (<= player.opacity 0.2)
               (not (= gamestate.status :COMPLETE)))
      (: reluctance :stop)
      (: (flux.to ring 1 { :radius (* ring.radius 1.5) :opacity (- ring.opacity 0.2) })
         :ease :cubicout)
      (: (flux.to player 0.5 { :x ring.x :y ring.y :opacity 1 :radius (* player.radius 0.9) :speed (* player.speed 1.1) })
         :ease :cubicout)))

(fn player.draw []
    (lg.setColor 0.16 0.16 0.16 player.opacity)
    (lg.circle :fill player.x player.y player.radius)
    (lg.setColor 0 0 0))

(fn ring.draw []
    (lg.setColor 0 0 0 ring.opacity)
    (lg.circle :line ring.x ring.y ring.radius)
    (lg.setColor 0 0 0))

(fn scene-update [dt]
    (flux.update dt)
    (when (> ring.radius player.radius)
      (if (lk.isDown :left)
          (move-player :x -1 dt)
          (lk.isDown :right)
          (move-player :x 1 dt)
          (lk.isDown :up)
          (move-player :y -1 dt)
          (lk.isDown :down)
          (move-player :y 1 dt))))

(fn scene-draw []
    (lg.setBackgroundColor 0.917 0.917 0.917)
    (ring.draw)
    (player.draw))

(fn scene-keypressed [key]
    (when (~= key nil) (: reluctance :stop))
    (when (= key :c) (set-gamestate-status :COMPLETE)))

(local main-scene { :update scene-update :draw scene-draw :keypressed scene-keypressed })

(local global-key-map { })
;; ===============

(fn love.keypressed [key]
    (when (= key :p)
      (if (= gamestate.status :RUNNING)
          (set-gamestate-status :PAUSED)
          (set-gamestate-status :RUNNING)))
    (when (= key :q) (quit-game))
    (main-scene.keypressed key))

(fn love.load [] 
    (register-callback
     :status-hooks
     (fn game-started []
         (when (= gamestate.status :STARTED)
           (set-gamestate-status :RUNNING)
           (: (flux.to player 1 { :radius 28 })
              :after
              ring 1 { :radius (* 32 1.15) }))))

    (register-callback
     :status-hooks
     (fn game-stopping []
         (when (= gamestate.status :STOPPING)
           (set-gamestate-status :STOPPED))))

    (register-callback
     :status-hooks
     (fn game-stopped []
         (when (= gamestate.status :STOPPED)
           (le.quit))))

    (register-callback
     :status-hooks
     (fn game-complete []
         (when (= gamestate.status :COMPLETE)
           (: reluctance :stop)
           (la.play gong)
           (flux.to ring 2 { :opacity 0 })
           (flux.to player 2 { :opacity 0 }))))

    (let [[width height] [(lg.getDimensions)]]
      (set ring.x (math.floor (/ width 2)))
      (set ring.y (math.floor (/ height 2)))
      (set player.x ring.x)
      (set player.y ring.y))
    
    (set-gamestate-status :STARTED))

(fn love.update [dt]
    (when (not (= gamestate.status :PAUSED))
      (each [key callback (pairs global-key-map)]
            (when (and (lk.isDown key)
                       (= (type callback) :function))
              (callback)))
      
      (when (and (= gamestate.status :COMPLETE) (: gong :isPlaying))
        (: gong :setVolume (- (: gong :getVolume) (/ dt 4)))
        (when (<= (: gong :getVolume) 0.01)
          (: gong :stop)
          (quit-game)))

      (main-scene.update dt)))

(fn love.draw []
    (main-scene.draw))

(fn love.keyreleased []
    (when (not (= gamestate.status :COMPLETE))
      (set reluctance (start-reluctance))))



