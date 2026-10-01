#!/bin/sh

for filename in ~/Library/Logs/DiagnosticReports/DashNews*.crash; do
    cat $filename
done