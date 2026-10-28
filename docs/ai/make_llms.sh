#!/bin/bash
# Rebuild llms-full.txt (top folder and docs/ai) and the docs/ai copy of
# AGENTS.md from AGENTS.md and the docs/ai guides. Run after editing
# any of them; tests/docs_test.sh fails when they are out of date.
TOPdir=$(cd "$(dirname "$0")/../.." && pwd)
A="${TOPdir}/docs/ai"
cp -f "${TOPdir}/AGENTS.md" "${A}/AGENTS.md"
{
    echo "# DRSM: all AI assistant guides in one file"
    echo ""
    echo "Built by docs/ai/make_llms.sh from AGENTS.md and docs/ai/*.md."
    for f in "${TOPdir}/AGENTS.md" "${A}/maintain-a-site.md" "${A}/write-a-plugin.md" "${A}/change-the-dashboard.md"; do
	echo ""
	echo "----------------------------------------------------------------"
	echo "File: ${f#"${TOPdir}"/}"
	echo "----------------------------------------------------------------"
	echo ""
	cat "${f}"
    done
} > "${TOPdir}/llms-full.txt"
cp -f "${TOPdir}/llms-full.txt" "${A}/llms-full.txt"
echo "Wrote ${TOPdir}/llms-full.txt, ${A}/llms-full.txt and ${A}/AGENTS.md"
