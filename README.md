# Ci::Master

Main propose of this gem to manage CI configuration accross all repos in [metanorma organization](https://github.com/metanorma)

## Installation

Highly likelly this gem will not be published, because it's only for internal usage

### Prerequisites

- [`repo`](https://source.android.com/setup/build/downloading#installing-repo)
- `pip install git-plus`
- `brew install hub`

## Usage

### Checkout all repos

These steps _need to be done once_, then you can reuse `$mn-root` for future CI configuration updates

- `mkdir $mn-root`
- `cd $mn-root`
- `repo init -u https://github.com/metanorma/metanorma-build-scripts`
- `repo sync`
- `echo 'metanorma-build-scripts' > .multigit_ignore`
- `git clone https://github.com/metanorma/ci-master.git`
- `cd ci-master`

### Make sure repos up-to-date

Command below need to keep your `$mn-root` up-to-date

- `bin/ci-master pull -b master -c ../metanorma-build-scripts/ci-master/config -r ../` - from `$mn-root/ci-master` directory

### Propogate changes from ci-master

Once you pushed your configuration updates to https://github.com/metanorma/metanorma-build-scripts you are ready to apply them for all repos:

- `bin/ci-master sync -r ../ -c ../metanorma-build-scripts/ci-master/config` - from `$mn-root/ci-master` directory
- `cd $mn-root`

If you just wanna _push to `master`_ run commands below:

- `git multi -c add -u .github`
- `git multi commit -m "Update CI configuration due to XXX feature"`

If you wanna to _create PR_ for your changes run commands below:

- `git multi -c checkout -b feature/xxx`
- `git multi -c add -u .github`
- `git multi commit -m "Update CI configuration due to XXX feature"`
- `git multi push --set-upstream github feature/xxx`
- `for f in */; do if [ -d "$f/.git" ]; then cd $f; hub pull-request -b master -r ronaldtse -a $GITHUBUSER_NAME --no-edit; cd ..; fi; done`

### Updating default.xml

From time to time we are renaming or adding new repos this is why we need to update it from time to time

 - `bin/gh-repo-manifest -o metanorma,relaton`
 
### Updaing specific groups

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/metanorma/metanorma-build-scripts. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## Code of Conduct

Everyone interacting in the Ci::Master project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/metanorma/metanorma-build-scripts/blob/master/ci-master/CODE_OF_CONDUCT.md).
