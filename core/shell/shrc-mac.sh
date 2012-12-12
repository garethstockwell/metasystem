# shrc-mac.sh

function gvim()
{
	file=$1
	[[ -n $file && ! -e $file ]] && touch $file
	open -a MacVim $file
}

