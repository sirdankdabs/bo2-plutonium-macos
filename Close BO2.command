#!/bin/bash
# Stop everything running in the BO2 Wine prefix.
here=$(cd -- "$(dirname -- "$0")" && pwd)
exec "$here/run-bo2.sh" kill
