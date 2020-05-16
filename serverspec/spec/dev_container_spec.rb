require_relative 'spec_helper'

describe 'dev-container' do
  describe 'node' do
    describe file('/usr/local/bin/node') do
      it { is_expected.to be_executable }
    end

    [
      [:node, /14.2/],
      [:npm, /6.14/]
    ].each do |executable, version|
      describe command("#{executable} -v") do
        its(:stdout) { is_expected.to match(version) }
      end
    end

    describe command('npm doctor') do
      its(:exit_status) { is_expected.to eq 0 }
    end
  end

  describe 'shell' do
    %i[shellcheck].each do |executable|
      describe file("/usr/bin/#{executable}") do
        it { is_expected.to be_executable }
      end
    end
  end

  describe 'fly' do
    describe command('fly -v') do
      its(:stdout) { is_expected.to match(/6.0.0/) }
    end
  end
end
