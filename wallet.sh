#!/bin/bash

input_name()
{
	if [ "$#" = "1" ]; then
		name="$1"
		return 0
	fi
	printf "请输入名称："
	read -r name
	if [ -z "$name" ]; then
		echo "名称不能为空！"
		return 1
	fi
	printf "%s" "$name" | grep '[ [:punct:]	]' >/dev/null 2>&1
	if [ "$?" -ne "1" ]; then
		echo "名称不能包含标点符号和空格！"
		return 1
	fi
	return 0
}

get_name()
{
	if [ "$#" = "0" ]; then
		select opt in `list`
		do
			if [ -n "$opt" ]; then
				name="$opt"
				return 0
			else
				echo "操作取消"
				return 1
			fi
		done
	else
		name="$1"
		return 0
	fi
	return 1
}

create()
{
	input_name "$@" || return 1
	show "$name" > /dev/null
	if [ "$?" = "0" ]; then
		echo "密码项 $name 已经存在！"
		return 1
	fi
	printf "%s 的值：" "$name"
	read -r -s value
	if [ -z "$content" ]; then
		content=`printf "%s%s" "$content" "$name: $value"`
	else
		content=`printf "%s\n%s" "$content" "$name: $value"`
	fi
	echo
}

delete()
{
	get_name "$@" || return 1
	# 删除空行
	name=`printf "%s" "$name" | sed '/^$/d'`
	content=`printf "%s" "$content" | sed -e "/^$name:/d"`
}

update()
{
	get_name "$@" || return 1
	delete "$name"
	create "$name"
}

show()
{
	get_name "$@" || return 1
	printf "%s" "$content" | grep "^$name:"
}

list()
{
	printf "%s" "$content" | sed -e "s/:.*$//g"
}

save()
{
	printf "%s" "$content" | openssl aes-256-cbc -salt -pass env:wallet_token -out "$wallet_file"
}

change_password()
{
	printf "请输入当前的密码："
	read -r -s token
	if [ "$token" != "$wallet_token" ]; then
		printf "\n密码错误！\n"
		return 1
	fi
	printf "\n请输入新密码："
	read -r -s new_token
	printf "\n请确认新密码："
	read -r -s token
	if [ "$token" != "$new_token" ]; then
		printf "\n两次输入的密码不一致！\n"
		return 1
	fi
	wallet_token="$new_token"
	printf "\n修改密码成功！\n"
	return 0
}

usage()
{
	echo '用法：wallet.sh'
	echo '命令: new, rm, update, show, passwd, quit'
}

if [ "$#" -gt "0" ]; then
	usage
	exit 1
fi

wallet_file="$HOME/.wallet-posixfung"
if [ -f "$wallet_file" ]; then
	printf "请输入钱包密码："
	read -r -s wallet_token
	export wallet_token
	content=`openssl aes-256-cbc -d -salt -pass \
			env:wallet_token -in "$wallet_file"`
	if [ "$?" != "0" ]; then
		echo '解密失败！'
		exit 1
	fi
else
	printf "钱包不存在，需要创建一个钱包\n"
	printf "请输入钱包的密码："
	read -r -s wallet_token
	echo
	export wallet_token
	if [ -z "$wallet_token" ]; then
		echo "密码不能为空"
		exit 1
	fi

	printf "再次输入以确认密码："
	read -r -s token
	echo
	if [ "$wallet_token" != "$token" ]; then
		echo "两次输入的密码不一致！"
		exit 1
	fi
	content=""
	unset token
fi

trap "" INT
echo
usage
while true
do
	printf "\nwallet> "
	read cmd
	case "$cmd" in
		"new"    ) create ;;
		"rm"     ) delete ;;
		"update" ) update ;;
		"show"   ) show ;;
		"passwd" ) change_password ;;
		""       ) clear; usage ;;
		"quit"   )
			echo; save
			content=""; export wallet_token=""; exit 0
			;;
		* ) usage ;;
	esac
done
