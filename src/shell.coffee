# Description:
#   Runs a script
#
# Commands:
#   hubot help <command> - Runs command

sys = require 'sys'
spawn = require('child_process').spawn
exec = require('child_process').exec
env = process.env
fs = require 'fs'

# Make sure our environment is configured properly
env.HUBOT_ENV           = env.HUBOT_ENV           || 'production'
env.HUBOT_SHELL_SCRIPTS = env.HUBOT_SHELL_SCRIPTS || '/srv/hubot/scripts'

env.PATH = env.HUBOT_SHELL_SCRIPTS + ":" + env.PATH

module.exports = (robot) ->
  robot.logger.info "loaded shell plugin"
  commands = fs.readdirSync(env.HUBOT_SHELL_SCRIPTS)
  robot.logger.debug "loaded commands: #{commands.join(",")}"

  robot.respond /([\w]+) ?(.*?)/i, (msg) ->
      # SECURITY scrub command of shell characters JUST TO BE SAFE. This isn't our
      # only line of protection. Using spawn means the shell won't interpret arguments
      # but its possible some commands use arguments in a way that could be
      # exploited so we scrub it here just to be safe.
      command = msg.match[1].toLowerCase().replace(/[`|'";&$!{}<>]/gm, '')
      args    = (msg.match[2] || '').replace(/[`|'";&$!{}<>]/gm, '')
      argv    = args.split(' ').filter (s) -> return s != '' # "

      return if command not in commands

      childEnv = Object.create(process.env)

      childEnv.HUBOT_CHAT_USER           = msg.message.user.name
      childEnv.HUBOT_CHAT_ROOM           = msg.message.room
      childEnv.HUBOT_CHAT_MESSAGE_ID     = msg.message.id

      buf = ''
      robot.logger.debug command
      child = spawn(command , argv, env: childEnv)

      child.stdout.on 'data', (data) -> buf += data.toString()
      child.stderr.on 'data', (data) -> buf += 'stderr: ' + data.toString()

      # Use the 'close' event instead of 'exit' (latter
      # Does not wait for termination of child streams)
      child.on 'close', (code, signal) ->
        helpOutput = code is 2 or command is 'help'
        if code isnt 0 and not helpOutput
          buf += "\n[exit: " + code + "]\n"

        if !buf.match /\n.+$/m
          if !buf.match /^http.*(png|jpg|gif)$/
            buf += "\n\n" # force campfire paste

        msg.send buf

      robot.logger.info "Waiting on the child for #{command}"

