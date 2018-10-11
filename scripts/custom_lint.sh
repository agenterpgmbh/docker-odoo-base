#!/usr/bin/env bash

function usage()
{
    echo "usage: -f | --file -m | --module -p | --project"
}


function find_module()
{
    if [ -d "$1" ] ; then
        for file in $1/*; do
            if [ "$(basename $file)" == "__openerp__.py" ] || [ "$(basename $file)" == "__manifest__.py" ]; then
                echo 1
                return
            fi
        done
        echo 0
    else
        echo 0
    fi
}

exitcode=0
file=0
module=0
project=0

while [ "$1" != "" ]; do
    case $1 in
        -f | --file )           shift
                                file=1
                                ;;
        -m | --module )         shift
                                module=1
                                ;;
        -p | --project )        shift
                                project=1
                                ;;
        -h | --help )           usage
                                exit
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done

if [ "$file" == "1" ]; then
    for gitfile in $(git diff --name-only HEAD HEAD~2); do
        if [ "$gitfile" == "*.py" ]; then
            pylint --load-plugins=pylint_odoo -d all -e odoolint --output-format=text --msg-template='{path} {msg_id}:{line:3d},{column}: {obj}: {msg}' --reports=n ${gitfile}
            exitcode=$(($exitcode + $?))
        fi
    done
fi

if [ "$module" == "1" ]; then
    for gitfile in $(git diff --name-only HEAD HEAD~2); do
        directory=$(dirname ${gitfile})
        if [ "$directory" != "." ]; then
            found=0
            while [ "$found" != "1" ] && [ "$directory" != "." ]; do
                found=$(find_module ${directory})
                if [ "$found" == "1" ]; then
                   pylint --load-plugins=pylint_odoo -d all -e odoolint --output-format=text --msg-template='{path} {msg_id}:{line:3d},{column}: {obj}: {msg}' --reports=n ${directory}
                   exitcode=$(($exitcode + $?))
                   break
                else
                    directory=$(dirname ${directory})
                fi
            done
        fi
    done
fi

if [ "$project" == "1" ]; then
    if [ -d "modules" ]; then
        pylint --load-plugins=pylint_odoo -d all -e odoolint --output-format=text --msg-template='{path} {msg_id}:{line:3d},{column}: {obj}: {msg}' --reports=n modules/
        exitcode=$(($exitcode + $?))
    else
        pylint --load-plugins=pylint_odoo -d all -e odoolint --output-format=text --msg-template='{path} {msg_id}:{line:3d},{column}: {obj}: {msg}' --reports=n .
        exitcode=$(($exitcode + $?))
    fi
fi

exit ${exitcode}