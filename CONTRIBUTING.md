## Contributing to lockers

Hi there!
We’re thrilled that you’d like to contribute to this project.
Your help is essential for keeping this project great and for making it better.

## Branching Strategy

In general, contributors should develop on branches based off of `master` and
pull requests should be made against `master`.

## Branch cleanup
It is recommended that you commit code to your branches often. Prior to pushing
the code and submitting PRs, please try to clean up your branch by squashing
multiple commits together and amending commit messages as appropriate. See
these pages for details:
https://blog.carbonfive.com/2017/08/28/always-squash-and-rebase-your-git-commits
https://git-scm.com/book/en/v2/Git-Tools-Rewriting-History

## Submitting a pull request

1. Please read our [code of conduct](code-of-conduct.md] and [license](LICENSE).
1. [Fork](https://github.com/quic/lockers) and clone the repository.
1. Create a new branch based on `master`: `git checkout -b <my-branch-name> master`.
1. Make your changes, add tests, and make sure the tests still pass.
1. Commit your changes using the [DCO](http://developercertificate.org/). You can attest to the DCO by commiting with the **-s** or **--signoff** options or manually adding the "Signed-off-by".
1. Push to your fork and [submit a pull request](https://github.com/quic/lockers) from your branch to `master`.
1. Pat yourself on the back and wait for your pull request to be reviewed.

Here are a few things you can do that will increase the likelihood of your pull request to be accepted:

- Follow the existing style where possible.
- Write tests.
- Keep your change as focused as possible.
  If you want to make multiple independent changes, please submit them as separate pull requests.
- Write a [good commit message](http://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html).
