import React, { useState } from 'react'
import LinkNode from '../LinkNode'

/**
 * Create Category - Form for creating new categories
 *
 * Allows users to create categories maintained by themselves, any noder,
 * or any usergroup they belong to.
 */
const CreateCategory = ({ data }) => {
  const {
    error,
    mustLogin,
    forbidden,
    user_id,
    user_title,
    usergroups = [],
    category_type_id,
    guest_user_id,
    low_level_warning
  } = data

  const [categoryName, setCategoryName] = useState('')
  const [maintainer, setMaintainer] = useState(user_id || '')
  const [description, setDescription] = useState('')
  const [isSubmitting, setIsSubmitting] = useState(false)

  // Show error states
  if (mustLogin) {
    return (
      <div style={styles.container}>
        <h3 style={styles.heading}>Create Category</h3>
        <p>
          You must be <LinkNode nodeId={null} title="logged in" url="/login" /> to create a category.
        </p>
      </div>
    )
  }

  if (forbidden) {
    return (
      <div style={styles.container}>
        <h3 style={styles.heading}>Create Category</h3>
        <div style={styles.errorBox}>{error}</div>
      </div>
    )
  }

  if (error) {
    return (
      <div style={styles.container}>
        <h3 style={styles.heading}>Create Category</h3>
        <div style={styles.errorBox}>{error}</div>
      </div>
    )
  }

  const handleSubmit = async (e) => {
    e.preventDefault()

    if (!categoryName.trim()) {
      alert('Please enter a category name.')
      return
    }

    if (!description.trim()) {
      alert('Please enter a category description.')
      return
    }

    setIsSubmitting(true)

    try {
      // Submit to new category creation (op=new)
      const form = document.createElement('form')
      form.method = 'POST'
      form.action = window.location.pathname

      const fields = {
        node: categoryName,
        maintainer: maintainer,
        category_doctext: description,
        op: 'new',
        type: category_type_id
      }

      Object.entries(fields).forEach(([name, value]) => {
        const input = document.createElement('input')
        input.type = 'hidden'
        input.name = name
        input.value = value
        form.appendChild(input)
      })

      document.body.appendChild(form)
      form.submit()
    } catch (err) {
      console.error('Error creating category:', err)
      alert('Error creating category. Please try again.')
      setIsSubmitting(false)
    }
  }

  return (
    <div style={styles.container}>
      <p style={styles.breadcrumb}>
        <strong>
          <LinkNode nodeId={null} title="Everything2 Help" url="/title/Everything2+Help" />
          {' > '}
          <LinkNode nodeId={null} title="Everything2 Categories" url="/title/Everything2+Categories" />
        </strong>
      </p>

      <p>
        A <LinkNode nodeId={null} title="category" url="/title/category" /> is a way to group
        a list of related nodes. You can create a category that only you can edit, a category
        that anyone can edit, or a category that can be maintained by any{' '}
        <LinkNode nodeId={null} title="usergroup" url="/title/Everything2+Usergroups" /> you
        are a member of.
      </p>

      <p>The scope of categories is limitless. Some examples might include:</p>

      <ul>
        <li>{user_title}'s Favorite Movies</li>
        <li>The Definitive Guide To Star Trek</li>
        <li>Everything2 Memes</li>
        <li>Funny Node Titles</li>
        <li>The Best Books of All Time</li>
        <li>Albums {user_title} Owns</li>
        <li>Writeups About Love</li>
        <li>Angsty Poetry</li>
        <li>Human Diseases</li>
        <li>... the list could go on and on</li>
      </ul>

      <p>
        Before you create your own category you might want to visit the{' '}
        <LinkNode nodeId={null} title="category display page" url="/title/Display+Categories" />{' '}
        to see if you can contribute to an existing category.
      </p>

      {low_level_warning === 1 && (
        <div style={styles.warningBox}>
          Note that until you are at least Level 2, you can only add your own writeups to categories.
        </div>
      )}

      <form onSubmit={handleSubmit}>
        <div style={styles.formGroup}>
          <label style={styles.label}>
            <strong>Category Name:</strong>
          </label>
          <input
            type="text"
            value={categoryName}
            onChange={(e) => setCategoryName(e.target.value)}
            maxLength={255}
            size={50}
            style={styles.textInput}
            disabled={isSubmitting}
          />
        </div>

        <div style={styles.formGroup}>
          <label style={styles.label}>
            <strong>Maintainer:</strong>
          </label>
          <select
            value={maintainer}
            onChange={(e) => setMaintainer(e.target.value)}
            style={styles.select}
            disabled={isSubmitting}
          >
            <option value={user_id}>Me ({user_title})</option>
            <option value={guest_user_id}>Any Noder</option>
            {usergroups.map((ug) => (
              <option key={ug.node_id} value={ug.node_id}>
                {ug.title} (usergroup)
              </option>
            ))}
          </select>
        </div>

        <fieldset style={styles.fieldset}>
          <legend style={styles.legend}>Category Description</legend>
          <textarea
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            rows={10}
            cols={60}
            style={styles.textarea}
            className="formattable"
            disabled={isSubmitting}
          />
        </fieldset>

        <div style={styles.formGroup}>
          <button
            type="submit"
            style={styles.submitButton}
            disabled={isSubmitting}
          >
            {isSubmitting ? 'Creating...' : 'Create It!'}
          </button>
        </div>
      </form>
    </div>
  )
}

const styles = {
  container: {
    fontSize: '13px',
    lineHeight: '1.6',
    color: '#111',
    padding: '20px'
  },
  breadcrumb: {
    marginBottom: '15px',
    fontSize: '14px'
  },
  heading: {
    fontSize: '18px',
    fontWeight: 'bold',
    color: '#38495e',
    marginBottom: '15px'
  },
  errorBox: {
    padding: '15px',
    backgroundColor: '#ffebee',
    border: '1px solid #f44336',
    borderRadius: '4px',
    color: '#c62828',
    marginBottom: '20px'
  },
  warningBox: {
    padding: '15px',
    backgroundColor: '#fff3cd',
    border: '1px solid #ffc107',
    borderRadius: '4px',
    color: '#856404',
    marginBottom: '20px'
  },
  formGroup: {
    marginBottom: '20px'
  },
  label: {
    display: 'block',
    marginBottom: '8px'
  },
  textInput: {
    width: '100%',
    maxWidth: '600px',
    padding: '8px',
    fontSize: '13px',
    border: '1px solid #ccc',
    borderRadius: '4px',
    fontFamily: 'inherit'
  },
  select: {
    padding: '8px',
    fontSize: '13px',
    border: '1px solid #ccc',
    borderRadius: '4px',
    backgroundColor: 'white',
    minWidth: '300px'
  },
  fieldset: {
    border: '1px solid #38495e',
    borderRadius: '4px',
    padding: '15px',
    marginBottom: '20px'
  },
  legend: {
    fontSize: '14px',
    fontWeight: 'bold',
    color: '#38495e',
    padding: '0 10px'
  },
  textarea: {
    width: '100%',
    padding: '8px',
    fontSize: '13px',
    border: '1px solid #ccc',
    borderRadius: '4px',
    fontFamily: 'monospace',
    resize: 'vertical'
  },
  submitButton: {
    padding: '10px 20px',
    fontSize: '13px',
    fontWeight: 'bold',
    color: 'white',
    backgroundColor: '#4060b0',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer'
  }
}

export default CreateCategory
