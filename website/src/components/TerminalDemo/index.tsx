import React from 'react';
import s from './styles.module.css';

export default function TerminalDemo(): React.JSX.Element {
  return (
    <div className={s.terminalWindow}>
      <div className={s.terminalHeader}>
        <span className={`${s.dot} ${s.red}`} />
        <span className={`${s.dot} ${s.yellow}`} />
        <span className={`${s.dot} ${s.green}`} />
        <span className={s.title}>lazy-md v0.1.0</span>
      </div>
      <pre className={s.body}>
<span className={s.bar}>{' lazy-md v0.1.0                    Tab:panels  1:tree  2:preview  :q quit '}</span>
<span className={s.tree}>{' Files      '}</span><span className={s.gutter}>{' 1 '}</span><span className={s.h1}>{'# Welcome to lazy-md'}</span>{'          '}<span className={s.border}>{'|'}</span><span className={s.preview}> <span className={s.bold}>{'Welcome to lazy-md'}</span></span>
<span className={s.tree}>{'  \u{1F4C1} src    '}</span><span className={s.gutter}>{' 2 '}</span>{'                                  '}<span className={s.border}>{'|'}</span><span className={s.preview}> <span className={s.line}>{'\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550'}</span></span>
<span className={s.tree}>{'  \u{1F4C4} main   '}</span><span className={s.gutter}>{' 3 '}</span><span className={s.normal}>{'A **fast** terminal editor'}</span>{'       '}<span className={s.border}>{'|'}</span><span className={s.preview}> A <span className={s.bold}>{'fast'}</span> terminal editor</span>
<span className={s.tree}>{'  \u{1F4C4} README '}</span><span className={s.gutter}>{' 4 '}</span><span className={s.normal}>{'with *vim* keybindings.'}</span>{'         '}<span className={s.border}>{'|'}</span><span className={s.preview}> with <span className={s.italic}>{'vim'}</span> keybindings.</span>
<span className={s.tree}>{'            '}</span><span className={s.gutter}>{' 5 '}</span>{'                                  '}<span className={s.border}>{'|'}</span><span className={s.preview}></span>
<span className={s.tree}>{'            '}</span><span className={s.gutter}>{' 6 '}</span><span className={s.h2}>{'## Features'}</span>{'                       '}<span className={s.border}>{'|'}</span><span className={s.preview}> <span className={`${s.bold} ${s.tGreen}`}>{'Features'}</span></span>
<span className={s.tree}>{'            '}</span><span className={s.gutter}>{' 7 '}</span>{'                                  '}<span className={s.border}>{'|'}</span><span className={s.preview}> <span className={s.line}>{'\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500'}</span></span>
<span className={s.tree}>{'            '}</span><span className={s.gutter}>{' 8 '}</span><span className={s.list}>{'- '}</span><span className={s.normal}>{'Syntax highlighting'}</span>{'             '}<span className={s.border}>{'|'}</span><span className={s.preview}> <span className={s.bullet}>{'\u2022'}</span> Syntax highlighting</span>
<span className={s.tree}>{'            '}</span><span className={s.gutter}>{' 9 '}</span><span className={s.list}>{'- '}</span><span className={s.normal}>{'Live preview'}</span>{'                    '}<span className={s.border}>{'|'}</span><span className={s.preview}> <span className={s.bullet}>{'\u2022'}</span> Live preview</span>
<span className={s.tree}>{'            '}</span><span className={s.gutter}>{'10 '}</span><span className={s.list}>{'- '}</span><span className={s.code}>{'`plugin system`'}</span>{'                '}<span className={s.border}>{'|'}</span><span className={s.preview}> <span className={s.bullet}>{'\u2022'}</span> <span className={s.codePreview}>{'plugin system'}</span></span>
<span className={s.status}>{' NORMAL  README.md                                          Ln 1, Col 1 '}</span>
      </pre>
    </div>
  );
}
