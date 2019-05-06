import { deepPurple700 } from 'material-ui/styles/colors'

const description = `
TODO: Write description
`

export default {
  competitionTitle: 'VolgaCTF Final',
  primary1Color: deepPurple700,
  accent1Color: 'f2c50a',
  headerColor: '#fff',
  indexTitle: 'Hello there!',
  indexDescription: description,
  competitionLogo: {
    src: 'src/images/volgactf-logo.svg',
    style: {
      height: '55px',
      marginTop: '5px',
      marginRight: '20px'
    },
    dist: '/assets/images/volgactf-logo.svg'
  },
  competitionNotifyLogo: {
    src: 'src/images/volgactf-notify-logo.png',
    dist: '/assets/images/volgactf-notify-logo.png'
  }
}
