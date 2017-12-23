# deployer.rb
class Deployer
  APPLICATION_HOST = 'your-application-host'.freeze
  HOST_USER = 'remoteuser'.freeze
  APPLICATION_CONTAINER = 'lg201/application-container'.freeze
  APPLICATION_FILE = 'application.tar.gz'.freeze
  ALLOWED_ACTIONS = %w(deploy).freeze
  APPLICATION_PATH = 'blog'.freeze

  def initialize(action)
    @action = action
    abort('Invalid action.') unless ALLOWED_ACTIONS.include? @action
  end

  def execute!
    public_send(@action)
  end

  def deploy
    check_changed_files
    copy_gemfile
    compress_application
    build_application_container
    push_container
    remote_deploy
  end

  private

  def check_changed_files
    return unless `git -C #{APPLICATION_PATH} status --short | wc -l`
                  .to_i.positive?
    abort('Files changed, please commit before deploying.')
  end

  def copy_gemfile
    system("cp #{APPLICATION_PATH}/Gemfile* .")
  end

  def compress_application
    system("tar -zcf #{APPLICATION_FILE} #{APPLICATION_PATH}")
  end

  def build_application_container
    system("docker build -t #{APPLICATION_CONTAINER}:#{current_git_rev} .")
  end

  def push_container
    system("docker push #{APPLICATION_CONTAINER}:#{current_git_rev}")
  end

  def remote_deploy
    system("#{ssh_command} docker pull "\
           "#{APPLICATION_CONTAINER}:#{current_git_rev}")
    system("#{ssh_command} 'docker stop \$(docker ps -q)'")
    system("#{ssh_command} docker run "\
             "--name #{deploy_user} "\
             "#{APPLICATION_CONTAINER}:#{current_git_rev}")
  end

  def current_git_rev
    `git -C #{APPLICATION_PATH} rev-parse --short HEAD`.strip
  end

  def ssh_command
    "ssh #{HOST_USER}@#{APPLICATION_HOST}"
  end

  def git_user
    `git config user.email`.split('@').first
  end

  def deploy_user
    user = git_user
    timestamp = Time.now.utc.strftime('%d.%m.%y_%H.%M.%S')
    "#{user}-#{timestamp}"
  end
end

if ARGV.empty?
  abort("Please inform action: \n\s- deploy")
end
application = Deployer.new(ARGV[0])

begin
  application.execute!
rescue Interrupt
  puts "\nDeploy aborted."
end
