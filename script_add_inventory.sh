if ! grep -qxF "$1" inventory
then
    echo $1 >> inventory
    echo $1 >> inventory.log
fi