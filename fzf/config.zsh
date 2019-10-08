export FZF_DEFAULT_OPTS='--preview "[[ $(file --mime {}) =~ binary ]] && \
                 echo {} is a binary file || \
                 (bat --style=numbers --color=always {} || \
                  highlight -O ansi -l {} || \
                  coderay {} || \
                  rougify {} || \
                  cat {}) 2> /dev/null | head -500"'


fpath+=("$DOTFILES/fzf")
 
function find_and_edit {
	query=$1

	if (($# == 0))
	then
		result=$(fzf)
	else
		result=$(fzf -q $1)
	fi

	if ! [[ -z $result ]];
	then
		$EDITOR $result
	fi
}
