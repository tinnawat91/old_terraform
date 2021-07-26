if ! grep -qxF "$1" inventory
then
    echo $1 >> inventory
fi