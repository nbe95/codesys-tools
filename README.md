# a-b-clear

Working with *ABB Automation Builder*? This tool leaves a lot of temporary files
behind and over time keeps cluttering your drive with them. Once you're
done working on a feature or a project, this simple shell script helps you to
find those temporary files and delete them accordingly.

> :bulb: If `trash` command is available, the files are moved to the recycle
bin. Otherwise, they will by irreversible destroyed by `rm`.

## Installation

Just add this shell script as it is to your setup as you like.

Example:

```sh
git clone https://github.com/nbe95/a-b-clear.git ~/.a-b-clear
sudo ln -s ~/.a-b-clear/clear.sh /usr/local/bin/a-b-clear
```

## Usage

Run `a-b-clear` with the directory of your choice. Use the `-r` flag to perform
a recursive lookup and clear all underlying project directories.

> :rotating_light: Any files are identified only by regex on their name!
Currently there's no dry-mode, so think twice before typing and - as usual -
**USE AT YOUR OWN RISK**.

![A nice screenshot](./doc/screenshot.png)
